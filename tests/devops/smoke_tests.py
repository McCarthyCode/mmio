"""
Smoke Tests for Staging and Production Deployments

These tests verify that the deployed application is responding correctly
and basic functionality is working in staging and production environments.
"""

import os
import sys
import requests
from urllib.parse import urljoin


class TestStagingHealthCheck:
    """Health checks for staging environment."""
    
    STAGING_URL = 'https://stage.mattmccarthy.io'
    TIMEOUT = 10
    
    def test_staging_health_check(self):
        """Test that staging endpoint is responding."""
        try:
            response = requests.get(
                self.STAGING_URL,
                timeout=self.TIMEOUT,
                allow_redirects=True
            )
            assert response.status_code == 200, f"Expected 200, got {response.status_code}"
        except requests.exceptions.RequestException as e:
            raise AssertionError(f"Staging health check failed: {e}")
    
    def test_staging_content_type(self):
        """Test that staging returns HTML content."""
        try:
            response = requests.get(
                self.STAGING_URL,
                timeout=self.TIMEOUT,
                allow_redirects=True
            )
            content_type = response.headers.get('content-type', '').lower()
            assert 'text/html' in content_type, f"Expected HTML, got {content_type}"
        except requests.exceptions.RequestException as e:
            raise AssertionError(f"Staging content-type check failed: {e}")
    
    def test_staging_has_csp_header(self):
        """Test that staging has CSP header configured."""
        try:
            response = requests.head(
                self.STAGING_URL,
                timeout=self.TIMEOUT,
                allow_redirects=True
            )
            assert 'content-security-policy' in response.headers, \
                "CSP header not found in staging response"
        except requests.exceptions.RequestException as e:
            raise AssertionError(f"Staging CSP header check failed: {e}")


class TestProductionHealthCheck:
    """Health checks for production environment."""
    
    PRODUCTION_URL = 'https://mattmccarthy.io'
    TIMEOUT = 10
    
    def test_production_health_check(self):
        """Test that production endpoint is responding."""
        try:
            response = requests.get(
                self.PRODUCTION_URL,
                timeout=self.TIMEOUT,
                allow_redirects=True
            )
            assert response.status_code == 200, f"Expected 200, got {response.status_code}"
        except requests.exceptions.RequestException as e:
            raise AssertionError(f"Production health check failed: {e}")
    
    def test_production_content_type(self):
        """Test that production returns HTML content."""
        try:
            response = requests.get(
                self.PRODUCTION_URL,
                timeout=self.TIMEOUT,
                allow_redirects=True
            )
            content_type = response.headers.get('content-type', '').lower()
            assert 'text/html' in content_type, f"Expected HTML, got {content_type}"
        except requests.exceptions.RequestException as e:
            raise AssertionError(f"Production content-type check failed: {e}")
    
    def test_production_has_csp_header(self):
        """Test that production has CSP header configured."""
        try:
            response = requests.head(
                self.PRODUCTION_URL,
                timeout=self.TIMEOUT,
                allow_redirects=True
            )
            assert 'content-security-policy' in response.headers, \
                "CSP header not found in production response"
        except requests.exceptions.RequestException as e:
            raise AssertionError(f"Production CSP header check failed: {e}")
    
    def test_production_has_ssl(self):
        """Test that production is using HTTPS."""
        try:
            response = requests.get(
                'http://mattmccarthy.io',
                timeout=self.TIMEOUT,
                allow_redirects=True
            )
            # Should redirect to HTTPS
            assert response.url.startswith('https://'), \
                "Production is not using HTTPS"
        except requests.exceptions.RequestException as e:
            raise AssertionError(f"Production SSL check failed: {e}")
