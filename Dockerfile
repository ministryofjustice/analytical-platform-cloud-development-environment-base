#checkov:skip=CKV_DOCKER_2: HEALTHCHECK not required - Health checks are implemented downstream of this image

FROM public.ecr.aws/ubuntu/ubuntu@sha256:288b44a1b2dfe3788255c3abd41e346bece153b9e066325f461f605425afaf82

LABEL org.opencontainers.image.vendor="Ministry of Justice" \
      org.opencontainers.image.authors="Analytical Platform (analytical-platform@digital.justice.gov.uk)" \
      org.opencontainers.image.title="Cloud Development Environment Base" \
      org.opencontainers.image.description="Cloud Development Environment base image for Analytical Platform" \
      org.opencontainers.image.url="https://github.com/ministryofjustice/analytical-platform-cloud-development-environment-base"

ENV CONTAINER_USER="analyticalplatform" \
    CONTAINER_UID="1000" \
    CONTAINER_GROUP="analyticalplatform" \
    CONTAINER_GID="1000" \
    ANALYTICAL_PLATFORM_DIRECTORY="/opt/analytical-platform" \
    DEBIAN_FRONTEND="noninteractive" \
    PIP_BREAK_SYSTEM_PACKAGES="1" \
    AWS_CLI_VERSION="2.17.26" \
    AWS_SSO_CLI_VERSION="1.17.0" \
    MINICONDA_VERSION="24.5.0-0" \
    MINICONDA_SHA256="4b3b3b1b99215e85fd73fb2c2d7ebf318ac942a457072de62d885056556eb83e" \
    NODE_LTS_VERSION="20.16.0" \
    CORRETTO_VERSION="1:21.0.4.7-1" \
    DOTNET_SDK_VERSION="8.0.107-0ubuntu1~24.04.1" \
    R_VERSION="4.4.1-1.2404.0" \
    OLLAMA_VERSION="0.3.4" \
    OLLAMA_SHA256="cb5ffdbe101adfd507c80fbfbbdd9997f6e3ef7afbb38f003349cd7c8b4c6055" \
    CUDA_VERSION="12.5.1" \
    NVIDIA_DISABLE_REQUIRE="true" \
    NVIDIA_CUDA_CUDART_VERSION="12.5.82-1" \
    NVIDIA_CUDA_COMPAT_VERSION="555.42.06-1" \
    NVIDIA_VISIBLE_DEVICES="all" \
    NVIDIA_DRIVER_CAPABILITIES="compute,utility" \
    LD_LIBRARY_PATH="/usr/local/nvidia/lib:/usr/local/nvidia/lib64" \
    PATH="/usr/local/nvidia/bin:/usr/local/cuda/bin:/opt/conda/bin:${HOME}/.local/bin:${PATH}"

SHELL ["/bin/bash", "-e", "-u", "-o", "pipefail", "-c"]

# User Configuration
# The "ubuntu" user is removed as it uses uid 1000, however we use uid 1000 to map home directories to EFS
RUN <<EOF
userdel --remove --force ubuntu

groupadd \
  --gid ${CONTAINER_GID} \
  ${CONTAINER_GROUP}

useradd \
  --uid ${CONTAINER_UID} \
  --gid ${CONTAINER_GROUP} \
  --create-home \
  --shell /bin/bash \
  ${CONTAINER_USER}
EOF

# Base Configuration
# Install a base set of packages and create the Analytical Platform directory
RUN <<EOF
apt-get update --yes

apt-get install --yes \
  "apt-transport-https=2.7.14build2" \
  "ca-certificates=20240203" \
  "curl=8.5.0-2ubuntu10.2" \
  "git=1:2.43.0-1ubuntu7.1" \
  "jq=1.7.1-3build1" \
  "mandoc=1.14.6-1" \
  "python3.12=3.12.3-1ubuntu0.1" \
  "python3-pip=24.0+dfsg-1ubuntu1" \
  "unzip=6.0-28ubuntu4"

apt-get clean --yes

rm --force --recursive /var/lib/apt/lists/*

install --directory --owner "${CONTAINER_USER}" --group "${CONTAINER_GROUP}" --mode 0755 "${ANALYTICAL_PLATFORM_DIRECTORY}"
EOF

# Init Configuration
# Copies init scripts to the Analytical Platform directory for use in entrypoints
COPY --chown="${CONTAINER_USER}:${CONTAINER_GROUP}" --chmod=755 src${ANALYTICAL_PLATFORM_DIRECTORY}/init ${ANALYTICAL_PLATFORM_DIRECTORY}/init

# Backup Bash Configuration
# Back up the default Bash configuration files so they can be restored later if needed
# When a tool launches for the first time mounted on EFS /home/${CONTAINER_USER} will be empty
RUN <<EOF
install --directory --owner "${CONTAINER_USER}" --group "${CONTAINER_GROUP}" --mode 0755 "${ANALYTICAL_PLATFORM_DIRECTORY}/bash-backup"

install --owner="${CONTAINER_USER}" --group="${CONTAINER_GROUP}" --mode=0644 "/home/${CONTAINER_USER}/.bashrc" "${ANALYTICAL_PLATFORM_DIRECTORY}/bash-backup/.bashrc"

install --owner="${CONTAINER_USER}" --group="${CONTAINER_GROUP}" --mode=0644 "/home/${CONTAINER_USER}/.bash_logout" "${ANALYTICAL_PLATFORM_DIRECTORY}/bash-backup/.bash_logout"

install --owner="${CONTAINER_USER}" --group="${CONTAINER_GROUP}" --mode=0644 "/home/${CONTAINER_USER}/.profile" "${ANALYTICAL_PLATFORM_DIRECTORY}/bash-backup/.profile"
EOF

# First Run Notice
# Copies a generic first-run-notice to the Analytical Platform directory and adds a snippet to the bash configuration to execute if using a valid terminal
COPY --chown=nobody:nobody --chmod=0644 src${ANALYTICAL_PLATFORM_DIRECTORY}/first-run-notice.txt ${ANALYTICAL_PLATFORM_DIRECTORY}/first-run-notice.txt
COPY src/etc/bash.bashrc.snippet /etc/bash.bashrc.snippet
RUN <<EOF
cat /etc/bash.bashrc.snippet >> /etc/bash.bashrc
EOF

# AWS CLI
# Installs AWS CLI (https://aws.amazon.com/cli/)
COPY --chown=nobody:nobody --chmod=0644 src/opt/aws-cli/aws-cli@amazon.com.asc /opt/aws-cli/aws-cli@amazon.com.asc
RUN <<EOF
gpg --import /opt/aws-cli/aws-cli@amazon.com.asc

curl --location --fail-with-body \
  "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip.sig" \
  --output "awscliv2.sig"

curl --location --fail-with-body \
  "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip" \
  --output "awscliv2.zip"

gpg --verify awscliv2.sig awscliv2.zip

unzip awscliv2.zip

./aws/install

rm --force --recursive awscliv2.sig awscliv2.zip aws
EOF

# AWS SSO CLI
# Installs AWS SSO CLI (https://github.com/synfinatic/aws-sso-cli)
COPY --chown="${CONTAINER_USER}:${CONTAINER_GROUP}" --chmod=0644 src${ANALYTICAL_PLATFORM_DIRECTORY}/aws-sso/config.yaml ${ANALYTICAL_PLATFORM_DIRECTORY}/aws-sso/config.yaml
# TODO: @jacobwoffenden - How do we make this persistent in the runtime environment?
ENV AWS_SSO_FILE_PASSWORD="analyticalplatform"
RUN <<EOF
curl --location --fail-with-body \
  "https://github.com/synfinatic/aws-sso-cli/releases/download/v${AWS_SSO_CLI_VERSION}/aws-sso-${AWS_SSO_CLI_VERSION}-linux-amd64" \
  --output "aws-sso"

install --owner "${CONTAINER_USER}" --group "${CONTAINER_GROUP}" --mode 0755 aws-sso /usr/local/bin/aws-sso

rm --force aws-sso
EOF

# Miniconda
# Installs Miniconda (https://docs.anaconda.com/miniconda/)
RUN <<EOF
curl --location --fail-with-body \
  "https://repo.anaconda.com/miniconda/Miniconda3-py312_${MINICONDA_VERSION}-Linux-x86_64.sh" \
  --output "miniconda.sh"

echo "${MINICONDA_SHA256} miniconda.sh" | sha256sum --check

bash miniconda.sh -b -p /opt/conda

chown --recursive "${CONTAINER_USER}":"${CONTAINER_GROUP}" /opt/conda

rm --force miniconda.sh
EOF

# NodeJS LTS
# Install NodsJS LTS (https://nodejs.org/)
RUN <<EOF
curl --location --fail-with-body \
  "https://deb.nodesource.com/setup_lts.x" \
  --output "node.sh"

bash node.sh

apt-get install --yes "nodejs=${NODE_LTS_VERSION}-1nodesource1"

apt-get clean --yes

rm --force --recursive /var/lib/apt/lists/* node.sh
EOF

# Amazon Corretto
# Install Amazon Corretto (https://aws.amazon.com/corretto/)
RUN <<EOF
curl --location --fail-with-body \
  "https://apt.corretto.aws/corretto.key" \
  --output corretto.key
cat corretto.key | gpg --dearmor --output corretto-keyring.gpg

install -D --owner root --group root --mode 644 corretto-keyring.gpg /etc/apt/keyrings/corretto-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main" > /etc/apt/sources.list.d/corretto.list

apt-get update --yes

apt-get install --yes "java-21-amazon-corretto-jdk=${CORRETTO_VERSION}"

apt-get clean --yes

rm --force --recursive corretto-keyring.gpg /var/lib/apt/lists/*
EOF

# .NET SDK
# Install .NET SDK (https://dotnet.microsoft.com/)
RUN <<EOF
apt-get update --yes

apt-get install --yes "dotnet-sdk-8.0=${DOTNET_SDK_VERSION}"

apt-get clean --yes

rm --force --recursive /var/lib/apt/lists/*
EOF

# R
# Install R (https://www.r-project.org/)
RUN <<EOF
curl --location --fail-with-body \
  "https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc" \
  --output "marutter_pubkey.asc"

cat marutter_pubkey.asc | gpg --dearmor --output marutter_pubkey.gpg

install -D --owner root --group root --mode 644 marutter_pubkey.gpg /etc/apt/keyrings/marutter_pubkey.gpg

echo "deb [signed-by=/etc/apt/keyrings/marutter_pubkey.gpg] https://cloud.r-project.org/bin/linux/ubuntu noble-cran40/" > /etc/apt/sources.list.d/cran.list

apt-get update --yes

apt-get install --yes "r-base=${R_VERSION}"

apt-get clean --yes

rm --force --recursive marutter_pubkey.asc marutter_pubkey.gpg /var/lib/apt/lists/*
EOF

# Ollama
RUN <<EOF
curl --location --fail-with-body \
  "https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/ollama-linux-amd64" \
  --output "ollama"

echo "${OLLAMA_SHA256} ollama" | sha256sum --check

install --owner=root --group=root --mode=775 ollama /usr/local/bin/ollama

rm --force ollama
EOF

# NVIDIA CUDA
# Installs NVIDIA drivers
RUN <<EOF
curl --location --fail-with-body \
  "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/3bf863cc.pub" \
  --output "3bf863cc.pub"

cat 3bf863cc.pub | gpg --dearmor --output nvidia.gpg

install -D --owner root --group root --mode 644 nvidia.gpg /etc/apt/keyrings/nvidia.gpg

echo "deb [signed-by=/etc/apt/keyrings/nvidia.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64 /" > /etc/apt/sources.list.d/cuda.list

apt-get update --yes

apt-get install --yes \
  "cuda-cudart-12-5=${NVIDIA_CUDA_CUDART_VERSION}" \
  "cuda-compat-12-5=${NVIDIA_CUDA_COMPAT_VERSION}"

echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf
echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf

apt-get clean --yes

rm --force --recursive 3bf863cc.pub /var/lib/apt/lists/*
EOF

USER ${CONTAINER_USER}
WORKDIR /home/${CONTAINER_USER}
