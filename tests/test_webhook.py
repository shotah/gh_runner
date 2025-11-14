"""
Tests for webhook Lambda function

Focused on security-critical and routing logic:
- Signature verification (security)
- Label matching (routing)
"""

import hashlib
import hmac
import sys
from pathlib import Path

# Add lambda/webhook to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / "lambda" / "webhook"))

from index import should_trigger_runner, verify_signature  # noqa: E402


class TestSignatureVerification:
    """Test GitHub webhook signature verification"""

    def test_verify_signature_valid(self):
        """Test that valid signatures are accepted"""
        secret = "my-webhook-secret"
        payload = '{"action":"queued","workflow_job":{}}'

        # Generate valid signature
        signature = (
            "sha256="
            + hmac.new(secret.encode("utf-8"), payload.encode("utf-8"), hashlib.sha256).hexdigest()
        )

        assert verify_signature(payload, signature, secret) is True

    def test_verify_signature_invalid(self):
        """Test that invalid signatures are rejected"""
        secret = "my-webhook-secret"
        payload = '{"action":"queued","workflow_job":{}}'
        invalid_signature = "sha256=invalid_signature_hash"

        assert verify_signature(payload, invalid_signature, secret) is False

    def test_verify_signature_empty_secret(self):
        """Test that empty secret rejects verification"""
        payload = '{"action":"queued","workflow_job":{}}'
        signature = "sha256=some_signature"

        assert verify_signature(payload, signature, "") is False

    def test_verify_signature_empty_signature(self):
        """Test that empty signature rejects verification"""
        secret = "my-webhook-secret"
        payload = '{"action":"queued","workflow_job":{}}'

        assert verify_signature(payload, "", secret) is False

    def test_verify_signature_wrong_secret(self):
        """Test that wrong secret rejects verification"""
        correct_secret = "correct-secret"
        wrong_secret = "wrong-secret"
        payload = '{"action":"queued","workflow_job":{}}'

        # Generate signature with correct secret
        signature = (
            "sha256="
            + hmac.new(
                correct_secret.encode("utf-8"), payload.encode("utf-8"), hashlib.sha256
            ).hexdigest()
        )

        # Verify with wrong secret should fail
        assert verify_signature(payload, signature, wrong_secret) is False

    def test_verify_signature_tampered_payload(self):
        """Test that tampered payload is detected"""
        secret = "my-webhook-secret"
        original_payload = '{"action":"queued","workflow_job":{}}'
        tampered_payload = '{"action":"completed","workflow_job":{}}'

        # Generate signature for original payload
        signature = (
            "sha256="
            + hmac.new(
                secret.encode("utf-8"), original_payload.encode("utf-8"), hashlib.sha256
            ).hexdigest()
        )

        # Verify with tampered payload should fail
        assert verify_signature(tampered_payload, signature, secret) is False


class TestLabelMatching:
    """Test workflow job label matching logic"""

    def test_should_trigger_with_self_hosted_label(self):
        """Test that jobs with 'self-hosted' label trigger runner"""
        workflow_job = {"labels": ["self-hosted", "linux", "x64"]}

        assert should_trigger_runner(workflow_job) is True

    def test_should_trigger_with_lambda_runner_label(self):
        """Test that jobs with 'lambda-runner' label trigger runner"""
        workflow_job = {"labels": ["lambda-runner", "python"]}

        assert should_trigger_runner(workflow_job) is True

    def test_should_trigger_with_both_labels(self):
        """Test that jobs with both labels trigger runner"""
        workflow_job = {"labels": ["self-hosted", "lambda-runner", "aws"]}

        assert should_trigger_runner(workflow_job) is True

    def test_should_not_trigger_without_matching_labels(self):
        """Test that jobs without matching labels don't trigger runner"""
        workflow_job = {"labels": ["ubuntu-latest", "x64"]}

        assert should_trigger_runner(workflow_job) is False

    def test_should_not_trigger_with_empty_labels(self):
        """Test that jobs with empty labels don't trigger runner"""
        workflow_job = {"labels": []}

        assert should_trigger_runner(workflow_job) is False

    def test_should_not_trigger_with_missing_labels_key(self):
        """Test that jobs without labels key don't trigger runner"""
        workflow_job = {}

        assert should_trigger_runner(workflow_job) is False

    def test_should_trigger_case_sensitive(self):
        """Test that label matching is case-sensitive"""
        # GitHub labels are case-sensitive
        workflow_job = {"labels": ["Self-Hosted", "LAMBDA-RUNNER"]}

        # Should not match because case is different
        assert should_trigger_runner(workflow_job) is False
