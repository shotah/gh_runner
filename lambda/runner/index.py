import json
import os
import subprocess
import time
import shutil
from pathlib import Path
from typing import Dict, Any
import boto3  # type: ignore
import requests  # type: ignore

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
    url = (
        f'https://api.github.com/repos/{repo_full_name}'
        '/actions/runners/registration-token'
    )
    headers = {
        'Authorization': f'token {github_token}',
        'Accept': 'application/vnd.github.v3+json'
    }

    response = requests.post(url, headers=headers)
    response.raise_for_status()

    return response.json()['token']


def setup_runner(work_dir: Path) -> Path:
    """
    Copy pre-installed runner to /tmp for execution
    (Lambda's /opt directory is read-only)
    """
    source_dir = Path('/opt/actions-runner')
    runner_dir = work_dir / 'runner'

    if not source_dir.exists():
        raise RuntimeError(
            'GitHub Actions runner not found at /opt/actions-runner'
        )

    # Read and log the installed version
    version_file = source_dir / 'version.txt'
    if version_file.exists():
        with open(version_file, 'r') as f:
            version = f.read().strip()
            print(
                f'Using pre-installed GitHub Actions runner '
                f'version: {version}'
            )
    else:
        print('Using pre-installed GitHub Actions runner (version unknown)')

    # Copy runner to /tmp (writable location)
    print(f'Copying runner from {source_dir} to {runner_dir}')
    shutil.copytree(source_dir, runner_dir, symlinks=True)

    return runner_dir


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
        if not github_token_secret:
            raise ValueError(
                'GITHUB_TOKEN_SECRET_NAME environment variable not set'
            )
        github_token = get_secret(github_token_secret)

        # Create working directory for runner execution
        work_dir = Path('/tmp/runner-work')
        work_dir.mkdir(exist_ok=True)

        # Copy pre-installed runner to /tmp (Lambda's /opt is read-only)
        runner_dir = setup_runner(work_dir)

        # Get registration token
        print('Getting registration token from GitHub')
        reg_token = get_registration_token(repo_full_name, github_token)

        # Configure runner as ephemeral (one-time use)
        runner_name = f'lambda-runner-{job_id}-{int(time.time())}'
        labels = (
            'self-hosted,lambda-runner,linux,x64,'
            'aws-cli,sam-cli,python,python3.13'
        )

        print(f'Configuring runner: {runner_name}')
        work_path = str(work_dir / 'work')
        config_cmd = [
            './config.sh',
            '--url', f'https://github.com/{repo_full_name}',
            '--token', reg_token,
            '--name', runner_name,
            '--labels', labels,
            '--work', work_path,  # Absolute path to writable /tmp
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
            timeout=840  # 14 minutes (leave 1 minute for cleanup)
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
        # Cleanup working directory
        try:
            work_dir = Path('/tmp/runner-work')
            if work_dir.exists():
                shutil.rmtree(work_dir)
        except Exception as e:
            print(f'Cleanup error: {str(e)}')
