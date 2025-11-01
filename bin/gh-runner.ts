#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { GithubRunnerStack } from '../lib/github-runner-stack';
import * as dotenv from 'dotenv';

// Load environment variables from .env file (if it exists)
dotenv.config();

const app = new cdk.App();

new GithubRunnerStack(app, 'GithubRunnerStack', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION,
  },
  description: 'Lambda-based GitHub Actions self-hosted runner with AWS CLI and SAM CLI',
});

