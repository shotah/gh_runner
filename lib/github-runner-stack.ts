import * as cdk from 'aws-cdk-lib';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager';
import * as ecr_assets from 'aws-cdk-lib/aws-ecr-assets';
import { Construct } from 'constructs';
import * as path from 'path';

export class GithubRunnerStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // ============================================
    // Tags - For Cost Tracking & Resource Management
    // ============================================
    
    cdk.Tags.of(this).add('Project', 'github-runner');
    cdk.Tags.of(this).add('ManagedBy', 'CDK');
    cdk.Tags.of(this).add('Environment', process.env.ENVIRONMENT || 'dev');
    cdk.Tags.of(this).add('CostCenter', process.env.COST_CENTER || 'Engineering');
    cdk.Tags.of(this).add('Owner', process.env.OWNER || 'DevOps');

    // ============================================
    // Secrets Manager - Store GitHub Token
    // ============================================
    
    // GitHub Personal Access Token (PAT) or GitHub App token
    // Can be provided via GITHUB_TOKEN environment variable during deployment
    const githubToken = process.env.GITHUB_TOKEN || 'REPLACE_ME';
    
    // Warn if token is not provided
    if (githubToken === 'REPLACE_ME') {
      console.warn('\n⚠️  WARNING: GITHUB_TOKEN environment variable not set!');
      console.warn('   The secret will be created with placeholder value.');
      console.warn('   You must update it before the runner can work:');
      console.warn('   aws secretsmanager put-secret-value --secret-id github-runner/token --secret-string "ghp_yourTokenHere"\n');
    }
    
    const githubTokenSecret = new secretsmanager.Secret(this, 'GithubToken', {
      secretName: 'github-runner/token',
      description: 'GitHub Personal Access Token or App token for runner registration',
      secretStringValue: cdk.SecretValue.unsafePlainText(githubToken),
    });

    // Optional: GitHub Webhook Secret for signature verification
    const webhookSecret = new secretsmanager.Secret(this, 'WebhookSecret', {
      secretName: 'github-runner/webhook-secret',
      description: 'GitHub webhook secret for signature verification',
      generateSecretString: {
        excludePunctuation: true,
        passwordLength: 32,
      },
    });

    // ============================================
    // Lambda - Runner Executor (with AWS CLI + SAM CLI)
    // ============================================
    
    // Build Docker image for runner
    const runnerImage = new ecr_assets.DockerImageAsset(this, 'RunnerImage', {
      directory: path.join(__dirname, '../lambda/runner'),
      platform: ecr_assets.Platform.LINUX_AMD64,
    });

    // Runner Lambda function
    const runnerFunction = new lambda.DockerImageFunction(this, 'RunnerFunction', {
      functionName: 'github-runner-executor',
      code: lambda.DockerImageCode.fromEcr(runnerImage.repository, {
        tagOrDigest: runnerImage.imageTag,
      }),
      timeout: cdk.Duration.minutes(15), // Maximum Lambda timeout
      memorySize: 3008, // High memory for faster execution
      ephemeralStorageSize: cdk.Size.gibibytes(10), // Max ephemeral storage
      environment: {
        GITHUB_TOKEN_SECRET_NAME: githubTokenSecret.secretName,
        // Note: Runner version is auto-detected from pre-installed runner in Docker image
      },
      logRetention: logs.RetentionDays.ONE_WEEK,
      // Note: No reserved concurrency - allows unlimited parallel jobs up to account limits
      // Uncomment to limit concurrent runners: reservedConcurrentExecutions: 10,
    });

    // Grant runner permissions
    githubTokenSecret.grantRead(runnerFunction);
    
    // ============================================
    // ⚠️  SECURITY WARNING: OVERLY BROAD PERMISSIONS
    // ============================================
    // These permissions grant near-admin access to many AWS services.
    // This is convenient for getting started but DANGEROUS in production!
    //
    // BEFORE DEPLOYING TO PRODUCTION:
    // 1. Review SECURITY.md for detailed scoping guidance
    // 2. Limit 'resources: ["*"]' to specific resource ARNs
    // 3. Remove unused service permissions (DynamoDB, SQS, etc.)
    // 4. Consider separate runner stacks per environment/team
    // 5. Use resource tags and IAM conditions for additional controls
    //
    // Remember: Any code in your GitHub workflows runs with these permissions!
    // ============================================
    
    runnerFunction.addToRolePolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: [
        // CloudFormation permissions for SAM deploy
        'cloudformation:CreateStack',
        'cloudformation:UpdateStack',
        'cloudformation:DeleteStack',
        'cloudformation:DescribeStacks',
        'cloudformation:DescribeStackEvents',
        'cloudformation:DescribeStackResource',
        'cloudformation:DescribeStackResources',
        'cloudformation:GetTemplate',
        'cloudformation:ValidateTemplate',
        'cloudformation:CreateChangeSet',
        'cloudformation:DescribeChangeSet',
        'cloudformation:ExecuteChangeSet',
        'cloudformation:DeleteChangeSet',
        'cloudformation:ListStackResources',
        // S3 permissions for SAM artifacts
        's3:CreateBucket',
        's3:PutObject',
        's3:GetObject',
        's3:DeleteObject',
        's3:ListBucket',
        's3:GetBucketLocation',
        's3:GetBucketVersioning',
        // Lambda permissions for SAM deploy
        'lambda:CreateFunction',
        'lambda:DeleteFunction',
        'lambda:GetFunction',
        'lambda:GetFunctionConfiguration',
        'lambda:UpdateFunctionCode',
        'lambda:UpdateFunctionConfiguration',
        'lambda:ListFunctions',
        'lambda:PublishVersion',
        'lambda:CreateAlias',
        'lambda:DeleteAlias',
        'lambda:GetAlias',
        'lambda:UpdateAlias',
        'lambda:AddPermission',
        'lambda:RemovePermission',
        'lambda:InvokeFunction',
        // IAM permissions for creating execution roles
        'iam:CreateRole',
        'iam:DeleteRole',
        'iam:GetRole',
        'iam:PassRole',
        'iam:AttachRolePolicy',
        'iam:DetachRolePolicy',
        'iam:PutRolePolicy',
        'iam:DeleteRolePolicy',
        'iam:GetRolePolicy',
        'iam:TagRole',
        // API Gateway permissions
        'apigateway:*',
        // CloudWatch Logs
        'logs:CreateLogGroup',
        'logs:CreateLogStream',
        'logs:PutLogEvents',
        'logs:DescribeLogGroups',
        'logs:DescribeLogStreams',
        // ECR permissions for Docker images
        'ecr:GetAuthorizationToken',
        'ecr:BatchCheckLayerAvailability',
        'ecr:GetDownloadUrlForLayer',
        'ecr:BatchGetImage',
        'ecr:PutImage',
        'ecr:InitiateLayerUpload',
        'ecr:UploadLayerPart',
        'ecr:CompleteLayerUpload',
        'ecr:CreateRepository',
        'ecr:DescribeRepositories',
        // SSM Parameter Store (commonly used)
        'ssm:GetParameter',
        'ssm:GetParameters',
        'ssm:PutParameter',
        // Secrets Manager
        'secretsmanager:GetSecretValue',
        'secretsmanager:CreateSecret',
        'secretsmanager:UpdateSecret',
        // DynamoDB (commonly used)
        'dynamodb:*',
        // SQS (commonly used)
        'sqs:*',
        // SNS (commonly used)
        'sns:*',
        // EventBridge (commonly used)
        'events:*',
        // Step Functions (commonly used)
        'states:*',
      ],
      resources: ['*'],
    }));

    // Output the runner function ARN
    new cdk.CfnOutput(this, 'RunnerFunctionArn', {
      value: runnerFunction.functionArn,
      description: 'ARN of the GitHub runner Lambda function',
    });

    // ============================================
    // Lambda - Webhook Receiver
    // ============================================
    
    const webhookFunction = new lambda.Function(this, 'WebhookFunction', {
      functionName: 'github-runner-webhook',
      runtime: lambda.Runtime.PYTHON_3_13,
      handler: 'index.handler',
      code: lambda.Code.fromAsset(path.join(__dirname, '../lambda/webhook')),
      timeout: cdk.Duration.seconds(30),
      memorySize: 256,
      environment: {
        GITHUB_WEBHOOK_SECRET_ARN: webhookSecret.secretArn,
        RUNNER_FUNCTION_NAME: runnerFunction.functionName,
      },
      logRetention: logs.RetentionDays.ONE_WEEK,
    });

    // Grant webhook function permissions
    webhookSecret.grantRead(webhookFunction);
    runnerFunction.grantInvoke(webhookFunction);

    // ============================================
    // API Gateway - Webhook Endpoint
    // ============================================
    
    const api = new apigateway.RestApi(this, 'WebhookApi', {
      restApiName: 'GitHub Runner Webhook',
      description: 'API Gateway for receiving GitHub webhook events',
      deployOptions: {
        stageName: 'prod',
        loggingLevel: apigateway.MethodLoggingLevel.INFO,
        dataTraceEnabled: true,
        metricsEnabled: true,
      },
      endpointConfiguration: {
        types: [apigateway.EndpointType.REGIONAL],
      },
    });

    // Add webhook endpoint
    const webhookIntegration = new apigateway.LambdaIntegration(webhookFunction, {
      proxy: true,
    });

    api.root.addMethod('POST', webhookIntegration);

    // Output the webhook URL
    new cdk.CfnOutput(this, 'WebhookUrl', {
      value: api.url,
      description: 'GitHub webhook URL - configure this in your GitHub repository/organization settings',
    });

    // ============================================
    // Outputs
    // ============================================
    
    new cdk.CfnOutput(this, 'GithubTokenSecretArn', {
      value: githubTokenSecret.secretArn,
      description: 'ARN of the GitHub token secret - update this with your actual token',
    });

    new cdk.CfnOutput(this, 'WebhookSecretArn', {
      value: webhookSecret.secretArn,
      description: 'ARN of the webhook secret - use this value in GitHub webhook configuration',
    });

    new cdk.CfnOutput(this, 'SetupInstructions', {
      value: 'See README.md for setup instructions',
      description: 'Next steps',
    });
  }
}

