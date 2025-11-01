FROM public.ecr.aws/lambda/python:3.13

# Install system dependencies
RUN yum update -y && \
    yum install -y \
    tar \
    gzip \
    git \
    wget \
    unzip \
    which \
    jq \
    && yum clean all

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

# Install AWS SAM CLI (latest version compatible with Python 3.13)
RUN pip install --no-cache-dir aws-sam-cli

# Download and install GitHub Actions runner (latest version)
RUN echo "Fetching latest GitHub Actions runner version..." && \
    RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/^v//') && \
    echo "Installing runner version: ${RUNNER_VERSION}" && \
    RUNNER_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" && \
    mkdir -p /opt/actions-runner && \
    curl -L ${RUNNER_URL} -o /tmp/runner.tar.gz && \
    tar -xzf /tmp/runner.tar.gz -C /opt/actions-runner && \
    rm /tmp/runner.tar.gz && \
    echo ${RUNNER_VERSION} > /opt/actions-runner/version.txt && \
    echo "GitHub Actions runner ${RUNNER_VERSION} installed successfully"

# Install Python dependencies for Lambda function
COPY requirements.txt ${LAMBDA_TASK_ROOT}/
RUN pip install --no-cache-dir -r ${LAMBDA_TASK_ROOT}/requirements.txt

# Copy Lambda function code
COPY index.py ${LAMBDA_TASK_ROOT}/

# Verify installations
RUN aws --version && sam --version && cat /opt/actions-runner/version.txt

# Set the CMD to your handler
CMD [ "index.handler" ]

