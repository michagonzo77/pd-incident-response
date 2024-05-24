# Use the specified base image
FROM ghcr.io/kubiyabot/kubiya-agent:stable
USER root

# Copy script
COPY /scripts/incident-response.sh /usr/local/bin/incident-response
RUN chmod +x /usr/local/bin/incident-response

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install python env libraries
COPY ./requirements.txt /requirements.txt
RUN /usr/local/bin/pip install --no-cache-dir -r /requirements.txt

USER appuser