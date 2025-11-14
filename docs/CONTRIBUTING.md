# Contributing to GitHub Actions Lambda Runner

Thank you for your interest in contributing! This document provides guidelines and information for contributors.

## Development Setup

1. **Clone the repository:**
```bash
git clone <repository-url>
cd gh_runner
```

2. **Install dependencies:**
```bash
npm install
```

3. **Build TypeScript:**
```bash
npm run build
```

4. **Watch mode (for development):**
```bash
npm run watch
```

## Project Structure

```
gh_runner/
├── bin/
│   └── gh-runner.ts          # CDK app entry point
├── lib/
│   └── github-runner-stack.ts # Main CDK stack
├── lambda/
│   ├── webhook/              # Webhook receiver Lambda
│   │   ├── index.py
│   │   └── requirements.txt
│   └── runner/               # Runner executor Lambda
│       ├── index.py
│       ├── requirements.txt
│       └── Dockerfile        # Docker image with AWS CLI/SAM
├── scripts/                  # Helper scripts
├── examples/                 # Example workflows
├── cdk.json                  # CDK configuration
├── package.json              # Node.js dependencies
└── README.md                 # Main documentation
```

## Making Changes

### TypeScript/CDK Changes

1. Make changes to files in `bin/` or `lib/`
2. Build: `npm run build`
3. Test locally: `cdk synth`
4. Preview changes: `cdk diff`

### Lambda Function Changes

#### Webhook Lambda (Python):
- Edit: `lambda/webhook/index.py`
- Dependencies: `lambda/webhook/requirements.txt`
- Test locally with Python 3.12

#### Runner Lambda (Python + Docker):
- Edit: `lambda/runner/index.py`
- Dependencies: `lambda/runner/requirements.txt`
- Dockerfile: `lambda/runner/Dockerfile`
- Build locally:
  ```bash
  cd lambda/runner
  docker build -t test-runner .
  docker run test-runner
  ```

### Testing Changes

1. **Lint TypeScript:**
```bash
npm run build
```

2. **Synth CloudFormation:**
```bash
cdk synth
```

3. **Deploy to test account:**
```bash
cdk deploy
```

4. **Test with actual workflow:**
   - Create test workflow in a repository
   - Trigger workflow
   - Monitor CloudWatch Logs

## Coding Standards

### TypeScript
- Use TypeScript strict mode
- Follow existing code style
- Use meaningful variable names
- Add comments for complex logic

### Python
- Follow PEP 8 style guide
- Use type hints where appropriate
- Add docstrings for functions
- Keep functions focused and small

### CDK Best Practices
- Use L2 constructs when available
- Add meaningful CloudFormation outputs
- Use tags for resource organization
- Follow AWS Well-Architected principles

## Pull Request Process

1. **Fork the repository**

2. **Create a feature branch:**
```bash
git checkout -b feature/your-feature-name
```

3. **Make your changes:**
   - Follow coding standards
   - Add tests if applicable
   - Update documentation

4. **Test thoroughly:**
   - Build succeeds
   - CDK synth works
   - Manual testing in AWS account

5. **Commit with clear messages:**
```bash
git commit -m "feat: add support for X"
git commit -m "fix: resolve issue with Y"
git commit -m "docs: update setup instructions"
```

6. **Push to your fork:**
```bash
git push origin feature/your-feature-name
```

7. **Open a Pull Request:**
   - Describe changes clearly
   - Reference any related issues
   - Include testing steps

## Commit Message Format

Use conventional commits:
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation only
- `style:` - Code style/formatting
- `refactor:` - Code refactoring
- `test:` - Adding tests
- `chore:` - Maintenance tasks

## Reporting Issues

When reporting issues, include:
1. Description of the problem
2. Steps to reproduce
3. Expected behavior
4. Actual behavior
5. Environment details (AWS region, Node version, etc.)
6. Relevant logs (CloudWatch, etc.)

## Feature Requests

For feature requests:
1. Check existing issues first
2. Describe the use case
3. Explain why it's valuable
4. Provide examples if possible

## Areas for Contribution

### High Priority
- GitHub App authentication support
- Improved error handling and retry logic
- Performance optimizations
- Cost optimization features
- Enhanced monitoring/metrics

### Documentation
- More example workflows
- Troubleshooting guides
- Architecture diagrams
- Video tutorials

### Testing
- Unit tests for Lambda functions
- Integration tests
- CDK snapshot tests
- Load testing

### Features
- Support for GitHub Enterprise
- Multi-region deployments
- Custom runner labels
- Job queuing system
- Metrics dashboard

## Development Tips

### Local Lambda Testing

Test webhook Lambda:
```python
cd lambda/webhook
python3 -c "from index import handler; print(handler({'body': '{}', 'headers': {}}, None))"
```

### CDK Debugging

Enable CDK debug output:
```bash
cdk deploy --verbose
```

### CloudWatch Insights Queries

Useful query for runner logs:
```sql
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 20
```

## Resources

- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Runner Documentation](https://github.com/actions/runner)

## Questions?

Feel free to open an issue for questions or discussions!

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
