import json
import os
import subprocess
import sys
import time
import shutil
from pathlib import Path
from typing import Dict, Any
import boto3
import requests

secretsmanager = boto3.client('secretsmanager')

def get_secret(secret_name: str) -> str:
    """Get secret from AWS Secrets Manager"""
    try:
        response = secretsmanager.get_secret_value(SecretId=secret_name)
        return response['SecretString']
    except Exception as e:
        print(f'Error retrieving secret {secret_name}: {str(e)}')
        raise

def get_registration_token(repo_full_name: str, github_token: str) -> str:
    """Get a registration token from GitHub API"""
    url = f'https://api.github.com/repos/{repo_full_name}/actions/runners/registration-token'
    headers = {
        'Authorization': f'token {github_token}',
        'Accept': 'application/vnd.github.v3+json'
    }
    
    response = requests.post(url, headers=headers)
    response.raise_for_status()
    
    return response.json()['token']

def get_runner_token(runner_url: str) -> str:
    """Get runner JIT config token for ephemeral runner"""
    # For JIT (Just-In-Time) configuration
    # This is more advanced and requires GitHub API v3
    # For now, we'll use registration token approach
    pass

def download_runner(work_dir: Path) -> Path:
    """Download GitHub Actions runner"""
    runner_version = os.environ.get('RUNNER_VERSION', '2.311.0')
    runner_url = f'https://github.com/actions/runner/releases/download/v{runner_version}/actions-runner-linux-x64-{runner_version}.tar.gz'
    
    runner_archive = work_dir / 'runner.tar.gz'
    runner_dir = work_dir / 'runner'
    runner_dir.mkdir(exist_ok=True)
    
    print(f'Downloading runner from {runner_url}')
    response = requests.get(runner_url, stream=True)
    response.raise_for_status()
    
    with open(runner_archive, 'wb') as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)
    
    print('Extracting runner')
    subprocess.run(['tar', '-xzf', str(runner_archive), '-C', str(runner_dir)], check=True)
    
    return runner_dir

def run_workflow_steps(workflow_job: Dict[str, Any], work_dir: Path) -> bool:
    """
    Execute workflow steps directly without full runner registration
    This is a simplified approach for Lambda
    """
    steps = workflow_job.get('steps', [])
    
    print(f'Executing {len(steps)} steps')
    
    for step in steps:
        step_name = step.get('name', 'Unnamed step')
        print(f'Step: {step_name}')
        
        # In a real implementation, you'd parse and execute the step
        # For now, this is a placeholder
        # The full runner binary handles this complexity
    
    return True

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Execute GitHub Actions workflow as an ephemeral runner
    """
    try:
        workflow_job = event.get('workflow_job', {})
        repository = event.get('repository', {})
        
        job_id = workflow_job.get('id')
        job_name = workflow_job.get('name')
        repo_full_name = repository.get('full_name')
        
        print(f'Processing job {job_id}: {job_name}')
        print(f'Repository: {repo_full_name}')
        
        # Get GitHub token from Secrets Manager
        github_token_secret = os.environ.get('GITHUB_TOKEN_SECRET_NAME')
        github_token = get_secret(github_token_secret)
        
        # Create working directory
        work_dir = Path('/tmp/runner')
        work_dir.mkdir(exist_ok=True)
        
        # Download and setup runner
        runner_dir = download_runner(work_dir)
        
        # Get registration token
        print('Getting registration token from GitHub')
        reg_token = get_registration_token(repo_full_name, github_token)
        
        # Configure runner as ephemeral (one-time use)
        runner_name = f'lambda-runner-{job_id}-{int(time.time())}'
        labels = 'self-hosted,lambda-runner,linux,x64,aws-cli,sam-cli,python,python3.13'
        
        print(f'Configuring runner: {runner_name}')
        config_cmd = [
            './config.sh',
            '--url', f'https://github.com/{repo_full_name}',
            '--token', reg_token,
            '--name', runner_name,
            '--labels', labels,
            '--work', '_work',
            '--ephemeral',  # Auto-remove after one job
            '--disableupdate',
            '--unattended'
        ]
        
        subprocess.run(
            config_cmd,
            cwd=runner_dir,
            check=True,
            capture_output=True,
            text=True
        )
        
        print('Starting runner')
        # Run the runner to pick up and execute the job
        run_result = subprocess.run(
            ['./run.sh'],
            cwd=runner_dir,
            capture_output=True,
            text=True,
            timeout=840  # 14 minutes (留1分钟给清理工作)
        )
        
        print(f'Runner stdout:\n{run_result.stdout}')
        if run_result.stderr:
            print(f'Runner stderr:\n{run_result.stderr}')
        
        if run_result.returncode != 0:
            print(f'Runner failed with exit code {run_result.returncode}')
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'Runner execution failed'})
            }
        
        print('Job completed successfully')
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Job completed',
                'job_id': job_id,
                'runner_name': runner_name
            })
        }
        
    except subprocess.TimeoutExpired:
        print('Runner execution timed out (approaching Lambda limit)')
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Execution timeout'})
        }
    except Exception as e:
        print(f'Error executing runner: {str(e)}')
        import traceback
        traceback.print_exc()
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
    finally:
        # Cleanup
        try:
            work_dir = Path('/tmp/runner')
            if work_dir.exists():
                shutil.rmtree(work_dir)
        except Exception as e:
            print(f'Cleanup error: {str(e)}')

