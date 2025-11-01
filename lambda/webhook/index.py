import json
import os
import hmac
import hashlib
import boto3  # type: ignore
from typing import Dict, Any

lambda_client = boto3.client('lambda')
secretsmanager = boto3.client('secretsmanager')

# Cache the webhook secret to avoid repeated Secrets Manager calls
_webhook_secret_cache = None


def get_webhook_secret() -> str:
    """Get webhook secret from Secrets Manager with caching"""
    global _webhook_secret_cache

    if _webhook_secret_cache is None:
        secret_arn = os.environ.get('GITHUB_WEBHOOK_SECRET_ARN', '')
        if secret_arn:
            try:
                response = secretsmanager.get_secret_value(
                    SecretId=secret_arn
                )
                _webhook_secret_cache = response['SecretString']
            except Exception as e:
                print(f'Error retrieving webhook secret: {str(e)}')
                return ''
        else:
            print('No webhook secret ARN configured')
            return ''

    return _webhook_secret_cache


def verify_signature(payload: str, signature: str, secret: str) -> bool:
    """Verify GitHub webhook signature using HMAC-SHA256"""
    if not signature or not secret:
        return False

    expected_signature = 'sha256=' + hmac.new(
        secret.encode('utf-8'),
        payload.encode('utf-8'),
        hashlib.sha256
    ).hexdigest()

    return hmac.compare_digest(expected_signature, signature)


def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Handle GitHub webhook events and trigger runner Lambda
    for workflow_job events
    """
    try:
        # Validate required environment variables
        runner_function_name = os.environ.get('RUNNER_FUNCTION_NAME', '')
        if not runner_function_name:
            raise ValueError(
                'RUNNER_FUNCTION_NAME environment variable not set'
            )

        # Get webhook secret from Secrets Manager
        webhook_secret = get_webhook_secret()

        # Verify signature
        signature = event.get('headers', {}).get('x-hub-signature-256', '')
        body = event.get('body', '')

        if not verify_signature(body, signature, webhook_secret):
            print('Invalid signature - webhook authentication failed')
            return {
                'statusCode': 401,
                'body': json.dumps({'error': 'Invalid signature'})
            }

        # Parse the event
        payload = json.loads(body)
        event_type = event.get('headers', {}).get('x-github-event', '')

        print(f'Received event: {event_type}')

        # Handle ping event
        if event_type == 'ping':
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'pong'})
            }

        # Handle workflow_job event
        if event_type == 'workflow_job':
            action = payload.get('action')
            workflow_job = payload.get('workflow_job', {})

            print(f'Workflow job action: {action}')
            print(f'Job ID: {workflow_job.get("id")}')
            print(f'Job status: {workflow_job.get("status")}')

            # Only trigger runner for 'queued' jobs
            if action == 'queued':
                labels = workflow_job.get('labels', [])
                print(f'Job labels: {labels}')

                # Check if this job is for our self-hosted runner
                # You can customize this check based on your labels
                if 'self-hosted' in labels or 'lambda-runner' in labels:
                    job_id = workflow_job.get("id")
                    print(f'Triggering runner for job {job_id}')

                    # Invoke runner Lambda asynchronously
                    try:
                        response = lambda_client.invoke(
                            FunctionName=runner_function_name,
                            InvocationType='Event',  # Async invocation
                            Payload=json.dumps({
                                'workflow_job': workflow_job,
                                'repository': payload.get('repository', {})
                            })
                        )
                        print(f'Runner invoked: {response}')
                    except Exception as e:
                        print(f'Error invoking runner: {str(e)}')
                        return {
                            'statusCode': 500,
                            'body': json.dumps({
                                'error': f'Failed to invoke runner: {str(e)}'
                            })
                        }
                else:
                    print(
                        'Job labels do not match '
                        'self-hosted runner criteria'
                    )

        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Event processed'})
        }

    except Exception as e:
        print(f'Error processing webhook: {str(e)}')
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
