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

# Install Python dependencies for Lambda function
COPY requirements.txt ${LAMBDA_TASK_ROOT}/
RUN pip install --no-cache-dir -r ${LAMBDA_TASK_ROOT}/requirements.txt

# Copy Lambda function code
COPY index.py ${LAMBDA_TASK_ROOT}/

# Verify installations
RUN aws --version && sam --version

# Set the CMD to your handler
CMD [ "index.handler" ]

