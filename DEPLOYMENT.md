# Deployment Documentation

## Overview

This document describes the CI/CD pipeline, deployment process, and environment configuration for the mmio application. The infrastructure has been redesigned to move away from manual EC2-based deployments ("cowboy coding") to a structured, serverless approach using AWS Lambda and GitHub Actions.

## Architecture

### Components

- **GitHub Actions**: CI/CD orchestration and automated testing
- **AWS Lambda**: Serverless application runtime for all environments
- **AWS HTTP API Gateway**: API routing and request handling
- **Container Registry**: GitHub Container Registry (GHCR) for Docker images
- **AWS SAM**: Infrastructure-as-code using CloudFormation templates

### Environments

The application runs in three distinct environments:

1. **Development** (`dev`)
   - Local development environment
   - Uses `config/env.development`
   - Debug logging enabled
   - No Lambda deployment

2. **Staging** (`stage.mattmccarthy.io`)
   - Pre-production testing environment
   - Uses `config/env.staging`
   - Lower resource allocation (512MB Lambda)
   - Deployed via GitHub Actions on main branch push
   - Separate Lambda function: `mmio-staging`

3. **Production** (`mattmccarthy.io`)
   - Live production environment
   - Uses `config/env.production`
   - Production-grade resource allocation (1024MB Lambda)
   - Deployed via GitHub Actions after staging validation
   - Separate Lambda function: `mmio-production`

## CI/CD Pipeline

### Workflow Overview

The GitHub Actions pipeline (`.github/workflows/ci-cd.yaml`) implements the following stages:

```
                    ┌─────────────┐
                    │   Trigger   │
                    │ (Push/PR)   │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │    Test     │
                    │ (DevOps)    │
                    └──────┬──────┘
                           │
            ┌──────────────┴──────────────┐
            │                             │
    ┌───────▼────────┐           ┌──────▼──────┐
    │   If PR/Fail   │           │  If Push    │
    │   → Notify     │           │   to Main   │
    └────────────────┘           └──────┬──────┘
                                        │
                                 ┌──────▼──────┐
                                 │    Build    │
                                 │   & Push    │
                                 │   Image     │
                                 └──────┬──────┘
                                        │
                                 ┌──────▼──────┐
                                 │   Deploy    │
                                 │  Staging    │
                                 └──────┬──────┘
                                        │
                                 ┌──────▼──────┐
                                 │  Deploy     │
                                 │ Production  │
                                 └─────────────┘
```

### Pipeline Jobs

#### 1. **Test Job**

Runs on all push and pull request events.

**Actions:**
- Checks out repository code
- Sets up Python environment
- Runs DevOps infrastructure tests
- Validates Docker configuration
- Validates docker-compose files

**Triggers:** All push and PR events
**Status:** Can fail without blocking merges

#### 2. **Build Job**

Runs only on push to `main` branch.

**Actions:**
- Checks out repository code
- Sets up Docker Buildx for multi-arch builds
- Authenticates with GitHub Container Registry (GHCR)
- Extracts image metadata (tags, SHA, version)
- Builds Docker image
- Pushes to GHCR with caching

**Triggers:** Push to main branch
**Status:** Required for deployment

#### 3. **Deploy Staging Job**

Runs only on successful build.

**Actions:**
- Configures AWS credentials (IAM role assumption)
- Updates Lambda function code with new image URI
- Waits for Lambda deployment to complete
- Runs staging smoke tests

**Triggers:** Build job success
**Environment:** Staging GitHub environment
**Status:** Required for production deployment

#### 4. **Deploy Production Job**

Runs only after staging deployment succeeds.

**Actions:**
- Configures AWS credentials (production IAM role)
- Updates Lambda function code with new image URI
- Waits for Lambda deployment to complete
- Runs production smoke tests
- Notifies on success

**Triggers:** Staging deployment success
**Environment:** Production GitHub environment
**Status:** Final deployment stage

## Environment Configuration

### Configuration Strategy

Each environment is configured via separate `.env` files in the `config/` directory:

- `config/env.development` - Local development
- `config/env.staging` - Staging environment
- `config/env.production` - Production environment

### Key Variables

| Variable | Purpose | Dev | Staging | Prod |
|----------|---------|-----|---------|------|
| `ENVIRONMENT` | Environment identifier | `development` | `staging` | `production` |
| `DEBUG` | Enable debug mode | `True` | `False` | `False` |
| `LOG_LEVEL` | Logging level | `DEBUG` | `INFO` | `WARN` |
| `FLASK_ENV` | Flask environment | `development` | `production` | `production` |
| `SECRET_KEY` | Flask secret key | `dev-key` | `${STAGING_SECRET_KEY}` | `${PRODUCTION_SECRET_KEY}` |

### Secret Management

Production secrets are managed through:

1. **GitHub Secrets**: Store sensitive values (e.g., `STAGING_SECRET_KEY`, `PRODUCTION_SECRET_KEY`)
2. **AWS IAM Roles**: Temporary credentials with time-limited access
3. **Environment Variables**: Injected at deployment time

**WARNING**: Never commit secrets to the repository. Use GitHub Secrets for sensitive data.

## AWS Lambda Configuration

### Infrastructure as Code

The application infrastructure is defined in `infrastructure/lambda-template.yaml` using AWS SAM (Serverless Application Model).

### Resource Allocation

| Environment | Memory | Timeout | Concurrency | Log Retention |
|-------------|--------|---------|-------------|----------------|
| Staging | 512 MB | 60 sec | 10 | 7 days |
| Production | 1024 MB | 60 sec | 100 | 30 days |

### Lambda Function Setup

#### Initial Deployment

```bash
# Install AWS SAM CLI
# https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html

# Deploy to staging
sam deploy \
  --template infrastructure/lambda-template.yaml \
  --stack-name mmio-staging \
  --parameter-overrides \
    Environment=staging \
    ContainerImage=ghcr.io/mccarthycode/mmio:main-<SHA> \
  --capabilities CAPABILITY_IAM \
  --region us-east-1

# Deploy to production
sam deploy \
  --template infrastructure/lambda-template.yaml \
  --stack-name mmio-production \
  --parameter-overrides \
    Environment=production \
    ContainerImage=ghcr.io/mccarthycode/mmio:main-<SHA> \
  --capabilities CAPABILITY_IAM \
  --region us-east-1
```

#### Subsequent Updates

The GitHub Actions workflow automatically updates Lambda functions when images are pushed. Manual updates are only necessary in exceptional cases:

```bash
aws lambda update-function-code \
  --function-name mmio-staging \
  --image-uri ghcr.io/mccarthycode/mmio:main-<SHA> \
  --region us-east-1
```

## Testing

### DevOps Tests

Infrastructure and configuration tests are located in `tests/devops/`.

**Run tests locally:**

```bash
# Install dev dependencies
pip install -r requirements-dev.txt

# Run all DevOps tests
pytest tests/devops/ -v

# Run specific test class
pytest tests/devops/test_infrastructure.py::TestDockerConfiguration -v

# Run with coverage
pytest tests/devops/ --cov=. --cov-report=html
```

**Tests verify:**
- Docker configuration validity
- Environment files completeness
- GitHub Actions workflow structure
- AWS Lambda template validity
- Deployment readiness

### Smoke Tests

Smoke tests validate deployed environments in `tests/devops/smoke_tests.py`.

**Run staging smoke tests:**

```bash
pytest tests/devops/smoke_tests.py::TestStagingHealthCheck -v
```

**Run production smoke tests:**

```bash
pytest tests/devops/smoke_tests.py::TestProductionHealthCheck -v
```

**Tests verify:**
- Endpoint responsiveness (HTTP 200)
- Content-type correctness (HTML)
- Security headers (CSP)
- HTTPS enforcement (production)

## Required GitHub Secrets

Configure these secrets in your GitHub repository settings:

### IAM Roles for OIDC

```
AWS_ROLE_ARN_STAGING = arn:aws:iam::ACCOUNT_ID:role/github-actions-staging
AWS_ROLE_ARN_PRODUCTION = arn:aws:iam::ACCOUNT_ID:role/github-actions-production
```

### Environment-Specific Secrets

```
STAGING_SECRET_KEY = <randomly generated 32+ character string>
PRODUCTION_SECRET_KEY = <randomly generated 32+ character string>
```

## Development Workflow

### Local Development

```bash
# Set environment variables
export $(cat config/env.development | xargs)

# Install dependencies
pip install flask gunicorn

# Run Flask development server
python -m flask run

# Or use docker-compose
docker-compose -f docker-compose.dev.yaml up
```

### Creating a Feature Branch

```bash
# Create feature branch
git checkout -b feature/my-feature

# Make changes and commit
git add .
git commit -m "feat: describe your changes"

# Push to GitHub
git push origin feature/my-feature

# Create Pull Request
# GitHub Actions will automatically test your changes
```

### Merging to Main

After PR approval and all tests passing:

```bash
# GitHub Actions will automatically:
# 1. Run tests
# 2. Build Docker image
# 3. Deploy to staging
# 4. Run staging smoke tests
# 5. Deploy to production
# 6. Run production smoke tests
```

## Troubleshooting

### Deployment Fails

1. **Check GitHub Actions logs:**
   - Navigate to repository → Actions → Workflow run
   - Review job logs for specific error

2. **Validate infrastructure:**
   ```bash
   # Test docker build locally
   docker build -t mmio:test .
   
   # Validate docker-compose
   docker-compose config
   
   # Validate CloudFormation template
   sam validate --template infrastructure/lambda-template.yaml
   ```

3. **Check Lambda logs:**
   ```bash
   aws logs tail /aws/lambda/mmio-staging --follow
   ```

### Lambda Function Not Responding

```bash
# Check function status
aws lambda get-function --function-name mmio-staging

# Test invocation
aws lambda invoke \
  --function-name mmio-staging \
  --payload '{"requestContext": {"http": {"method": "GET", "path": "/"}}}' \
  response.json

cat response.json
```

### Container Image Issues

```bash
# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USER --password-stdin

# Pull image
docker pull ghcr.io/mccarthycode/mmio:main-<SHA>

# Run locally for testing
docker run -p 8080:8080 ghcr.io/mccarthycode/mmio:main-<SHA>
```

## Rollback Procedure

If a production deployment causes issues:

```bash
# Get previous image URI from AWS Console or:
aws lambda get-function --function-name mmio-production

# Redeploy with previous image
aws lambda update-function-code \
  --function-name mmio-production \
  --image-uri ghcr.io/mccarthycode/mmio:main-<PREVIOUS_SHA>
```

## Monitoring and Alerts

### CloudWatch Metrics

Lambda functions expose the following metrics:

- **Invocations**: Number of function invocations
- **Duration**: Function execution time
- **Errors**: Number of errors
- **Throttles**: Function throttling events
- **ConcurrentExecutions**: Concurrent function executions

### Alarms

Alarms are configured in the CloudFormation template for:

- Lambda error rate threshold (>5 errors in 5 minutes)

**View alarms:**

```bash
aws cloudwatch describe-alarms --alarm-name-prefix mmio
```

## SDLC Best Practices

This infrastructure implements the following SDLC best practices:

✅ **Separation of Concerns**: Development, staging, and production are isolated environments
✅ **Infrastructure as Code**: All infrastructure defined in version-controlled YAML
✅ **Automated Testing**: Tests run automatically on every commit
✅ **Staged Deployments**: Changes validated in staging before production
✅ **Audit Trail**: All deployments tracked in GitHub Actions and AWS
✅ **Secrets Management**: Sensitive data in GitHub Secrets, never in code
✅ **Rollback Capability**: Easy rollback to previous versions
✅ **Monitoring**: CloudWatch metrics and alarms for observability

## Related Issues

- Issue #1: CSP Whitelist for Inline Scripts - Uses this infrastructure for deployment
- Related documentation: See AWS SAM, GitHub Actions, and serverless best practices

## References

- [AWS Serverless Application Model Documentation](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/what-is-sam.html)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [Container Image Support for Lambda](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html)
