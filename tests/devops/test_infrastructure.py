"""
DevOps Infrastructure Tests

Tests for Docker configuration, environment setup, and general deployment readiness.
Feature tests are out of scope for this suite.
"""

import subprocess
import json
import sys
from pathlib import Path


class TestDockerConfiguration:
    """Test Docker and docker-compose configuration."""
    
    def test_dockerfile_exists(self):
        """Test that Dockerfile exists in project root."""
        dockerfile = Path('Dockerfile')
        assert dockerfile.exists(), "Dockerfile not found in project root"
    
    def test_docker_compose_file_valid(self):
        """Test that docker-compose.yaml is valid."""
        result = subprocess.run(
            ['docker-compose', 'config'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"docker-compose config failed: {result.stderr}"
    
    def test_dockerfile_builds(self):
        """Test that Docker image builds successfully."""
        result = subprocess.run(
            ['docker', 'build', '-t', 'mmio:test', '.'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"Docker build failed: {result.stderr}"


class TestEnvironmentConfiguration:
    """Test environment configuration files."""
    
    def test_development_env_file_exists(self):
        """Test that development environment file exists."""
        env_file = Path('config/env.development')
        assert env_file.exists(), "config/env.development not found"
    
    def test_staging_env_file_exists(self):
        """Test that staging environment file exists."""
        env_file = Path('config/env.staging')
        assert env_file.exists(), "config/env.staging not found"
    
    def test_production_env_file_exists(self):
        """Test that production environment file exists."""
        env_file = Path('config/env.production')
        assert env_file.exists(), "config/env.production not found"
    
    def test_env_files_have_required_vars(self):
        """Test that environment files contain required variables."""
        required_vars = {'ENVIRONMENT', 'LOG_LEVEL', 'FLASK_ENV', 'FLASK_APP'}
        
        for env_file in Path('config').glob('env.*'):
            with open(env_file) as f:
                content = f.read()
            
            # Extract variable names
            vars_in_file = set()
            for line in content.split('\n'):
                if line.strip() and not line.startswith('#'):
                    if '=' in line:
                        var_name = line.split('=')[0].strip()
                        vars_in_file.add(var_name)
            
            missing = required_vars - vars_in_file
            assert not missing, f"{env_file} missing required vars: {missing}"


class TestGitHubActionsWorkflow:
    """Test GitHub Actions workflow configuration."""
    
    def test_ci_cd_workflow_exists(self):
        """Test that CI/CD workflow file exists."""
        workflow = Path('.github/workflows/ci-cd.yaml')
        assert workflow.exists(), "CI/CD workflow not found"
    
    def test_workflow_has_required_jobs(self):
        """Test that workflow contains required jobs."""
        import yaml
        
        workflow_file = Path('.github/workflows/ci-cd.yaml')
        with open(workflow_file) as f:
            workflow = yaml.safe_load(f)
        
        required_jobs = {'test', 'build', 'deploy-staging', 'deploy-production'}
        actual_jobs = set(workflow.get('jobs', {}).keys())
        
        missing_jobs = required_jobs - actual_jobs
        assert not missing_jobs, f"Workflow missing required jobs: {missing_jobs}"
    
    def test_workflow_has_proper_triggers(self):
        """Test that workflow triggers are properly configured."""
        import yaml
        
        workflow_file = Path('.github/workflows/ci-cd.yaml')
        with open(workflow_file) as f:
            workflow = yaml.safe_load(f)
        
        # Should trigger on push to main and PRs
        on_config = workflow.get('on', {})
        assert 'push' in on_config, "Workflow not triggered on push"
        assert 'pull_request' in on_config, "Workflow not triggered on PR"


class TestAWSLambdaConfiguration:
    """Test AWS Lambda infrastructure configuration."""
    
    def test_lambda_template_exists(self):
        """Test that Lambda CloudFormation template exists."""
        template = Path('infrastructure/lambda-template.yaml')
        assert template.exists(), "Lambda template not found"
    
    def test_lambda_template_valid(self):
        """Test that Lambda CloudFormation template is valid YAML."""
        import yaml
        
        template_file = Path('infrastructure/lambda-template.yaml')
        with open(template_file) as f:
            try:
                template = yaml.safe_load(f)
                assert template is not None, "Template is empty"
            except yaml.YAMLError as e:
                raise AssertionError(f"Template YAML is invalid: {e}")
    
    def test_lambda_template_has_required_parameters(self):
        """Test that Lambda template has required parameters."""
        import yaml
        
        template_file = Path('infrastructure/lambda-template.yaml')
        with open(template_file) as f:
            template = yaml.safe_load(f)
        
        required_params = {'Environment', 'ContainerImage'}
        actual_params = set(template.get('Parameters', {}).keys())
        
        missing_params = required_params - actual_params
        assert not missing_params, f"Template missing required parameters: {missing_params}"
    
    def test_lambda_template_has_required_resources(self):
        """Test that Lambda template defines required resources."""
        import yaml
        
        template_file = Path('infrastructure/lambda-template.yaml')
        with open(template_file) as f:
            template = yaml.safe_load(f)
        
        required_resources = {
            'LambdaExecutionRole',
            'MmioFunction',
            'MmioHttpApi',
        }
        actual_resources = set(template.get('Resources', {}).keys())
        
        missing_resources = required_resources - actual_resources
        assert not missing_resources, f"Template missing required resources: {missing_resources}"


class TestDeploymentReadiness:
    """Test overall deployment readiness."""
    
    def test_required_files_exist(self):
        """Test that all required deployment files exist."""
        required_files = [
            Path('Dockerfile'),
            Path('docker-compose.yaml'),
            Path('config/env.development'),
            Path('config/env.staging'),
            Path('config/env.production'),
            Path('.github/workflows/ci-cd.yaml'),
            Path('infrastructure/lambda-template.yaml'),
        ]
        
        missing_files = [f for f in required_files if not f.exists()]
        assert not missing_files, f"Missing required files: {missing_files}"
    
    def test_github_actions_environment_documented(self):
        """Test that GitHub Actions environments are properly documented."""
        doc_file = Path('DEPLOYMENT.md')
        assert doc_file.exists(), "DEPLOYMENT.md documentation not found"
        
        with open(doc_file) as f:
            content = f.read()
        
        required_sections = ['staging', 'production', 'environment variables']
        for section in required_sections:
            assert section.lower() in content.lower(), f"Documentation missing section: {section}"
