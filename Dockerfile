#checkov:skip=CKV_DOCKER_2: HEALTHCHECK not required - Health checks are implemented downstream of this image

FROM public.ecr.aws/ubuntu/ubuntu:24.04@sha256:932333528e27f2be8ae92535c4c3c2c1030a4cf368abbec1cf61d9ee8aa7cf41

LABEL org.opencontainers.image.vendor="Ministry of Justice" \
      org.opencontainers.image.authors="Analytical Platform (analytical-platform@digital.justice.gov.uk)" \
      org.opencontainers.image.title="Cloud Development Environment Base" \
      org.opencontainers.image.description="Cloud Development Environment base image for Analytical Platform" \
      org.opencontainers.image.url="https://github.com/ministryofjustice/analytical-platform-cloud-development-environment-base"

ENV ANALYTICAL_PLATFORM_DIRECTORY="/opt/analytical-platform" \
    AWS_CLI_VERSION="2.27.27" \
    AWS_SSO_CLI_VERSION="2.0.3" \
    CLOUD_PLATFORM_CLI_VERSION="1.46.0" \
    CONTAINER_GID="1000" \
    CONTAINER_GROUP="analyticalplatform" \
    CONTAINER_UID="1000" \
    CONTAINER_USER="analyticalplatform" \
    CORRETTO_VERSION="1:21.0.7.6-1" \
    CUDA_VERSION="12.9.0" \
    DEBIAN_FRONTEND="noninteractive" \
    DOTNET_SDK_VERSION="8.0.116-0ubuntu1~24.04.1" \
    HELM_VERSION="3.18.2" \
    KUBECTL_VERSION="1.30.13" \
    LANG="C.UTF-8" \
    LANGUAGE="C.UTF-8" \
    LC_ALL="C.UTF-8" \
    LD_LIBRARY_PATH="/usr/local/nvidia/lib:/usr/local/nvidia/lib64" \
    MICROSOFT_SQL_ODBC_VERSION="18.5.1.1-1" \
    MICROSOFT_SQL_TOOLS_VERSION="18.4.1.1-1" \
    MINICONDA_SHA256="8937a2c9a86cfc5495ba2234476f89686beff5c8e0569b1ed5771a927c75107b" \
    MINICONDA_VERSION="25.3.1-1" \
    NBSTRIPOUT_VERSION="0.8.1" \
    NODE_LTS_VERSION="22.16.0" \
    NVIDIA_CUDA_COMPAT_VERSION="575.51.03-0ubuntu1" \
    NVIDIA_CUDA_CUDART_VERSION="12.9.37-1" \
    NVIDIA_DISABLE_REQUIRE="true" \
    NVIDIA_DRIVER_CAPABILITIES="compute,utility" \
    NVIDIA_VISIBLE_DEVICES="all" \
    OLLAMA_VERSION="0.9.0" \
    PATH="/usr/local/nvidia/bin:/usr/local/cuda/bin:/opt/conda/bin:/home/analyticalplatform/.local/bin:/opt/mssql-tools18/bin:${PATH}" \
    PIP_BREAK_SYSTEM_PACKAGES="1" \
    R_VERSION="4.5.0-3.2404.0" \
    UV_VERSION="0.7.9"

# renovate: release=noble depName=apt-transport-https
ENV APT_TRANSPORT_HTTPS_VERSION="2.8.3"
# renovate: release=noble depName=ca-certificates
ENV CA_CERTIFICATES_VERSION="20240203"
# renovate: release=noble-updates depName=curl
ENV CURL_VERSION="8.5.0-2ubuntu10.6"
# renovate: release=noble-updates depName=git
ENV GIT_VERSION="1:2.43.0-1ubuntu7.2"
# renovate: release=noble depName=ffmpeg
ENV FFMPEG_VERSION="7:6.1.1-3ubuntu5"
# renovate: release=noble depName=jq
ENV JQ_VERSION="1.7.1-3build1"
# renovate: release=noble depName=mandoc
ENV MANDOC_VERSION="1.14.6-1"
# renovate: release=noble-updates depName=less
ENV LESS_VERSION="590-2ubuntu2.1"
# renovate: release=noble-updates depName=python3.12
ENV PYTHON3_12_VERSION="3.12.3-1ubuntu0.5"
# renovate: release=noble-updates depName=python3-pip
ENV PYTHON3_PIP_VERSION="24.0+dfsg-1ubuntu1.1"
# renovate: release=noble-updates depName=vim
ENV VIM_VERSION="2:9.1.0016-1ubuntu7.8"
# renovate: release=noble-updates depName=unixodbc
ENV UNIXODBC_VERSION="2.3.12-1ubuntu0.24.04.1"
# renovate: release=noble-updates depName=unzip
ENV UNZIP_VERSION="6.0-28ubuntu4.1"

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
  "apt-transport-https=${APT_TRANSPORT_HTTPS_VERSION}" \
  "ca-certificates=${CA_CERTIFICATES_VERSION}" \
  "curl=${CURL_VERSION}" \
  "git=${GIT_VERSION}" \
  "ffmpeg=${FFMPEG_VERSION}" \
  "jq=${JQ_VERSION}" \
  "mandoc=${MANDOC_VERSION}" \
  "less=${LESS_VERSION}" \
  "python3.12=${PYTHON3_12_VERSION}" \
  "python3-pip=${PYTHON3_PIP_VERSION}" \
  "vim=${VIM_VERSION}" \
  "unixodbc=${UNIXODBC_VERSION}" \
  "unzip=${UNZIP_VERSION}"

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
COPY --chown="${CONTAINER_USER}:${CONTAINER_GROUP}" --chmod=0644 src${ANALYTICAL_PLATFORM_DIRECTORY}/first-run-notice.txt ${ANALYTICAL_PLATFORM_DIRECTORY}/first-run-notice.txt
COPY src/etc/bash.bashrc.snippet /etc/bash.bashrc.snippet
RUN <<EOF
cat /etc/bash.bashrc.snippet >> /etc/bash.bashrc
EOF

# AWS CLI
# Installs AWS CLI (https://aws.amazon.com/cli/)
COPY --chown=nobody:nogroup --chmod=0644 src/opt/aws-cli/aws-cli@amazon.com.asc /opt/aws-cli/aws-cli@amazon.com.asc
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

install --owner nobody --group nogroup --mode 0755 aws-sso /usr/local/bin/aws-sso

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

# nbstripout
# Installs nbstripout (https://github.com/kynan/nbstripout)
RUN <<EOF
pip install --no-cache-dir "nbstripout==${NBSTRIPOUT_VERSION}"

nbstripout --install --system
EOF

# Node.js LTS
# Install Node.js LTS (https://nodejs.org/)
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

rm --force --recursive /var/lib/apt/lists/* corretto-keyring.gpg corretto.key
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

rm --force --recursive /var/lib/apt/lists/* marutter_pubkey.asc marutter_pubkey.gpg
EOF

# Ollama
RUN <<EOF
curl --location --fail-with-body \
  "https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/ollama-linux-amd64.tgz" \
  --output ollama-linux-amd64.tgz

curl --location --fail-with-body \
  "https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/sha256sum.txt" \
  --output ollama-sha256sum.txt

sha256sum --check --ignore-missing ollama-sha256sum.txt

tar -C /usr -xzf ollama-linux-amd64.tgz

rm --force --recursive ollama-linux-amd64.tgz ollama-sha256sum.txt
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
  "cuda-cudart-12-9=${NVIDIA_CUDA_CUDART_VERSION}" \
  "cuda-compat-12-9=${NVIDIA_CUDA_COMPAT_VERSION}"

echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf
echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf

apt-get clean --yes

rm --force --recursive /var/lib/apt/lists/* 3bf863cc.pub nvidia.gpg
EOF

# Kubernetes CLI
RUN <<EOF
curl --location --fail-with-body \
  "https://dl.k8s.io/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
  --output "kubectl"

install --owner nobody --group nogroup --mode 0755 kubectl /usr/local/bin/kubectl

rm --force kubectl
EOF

# Helm
RUN <<EOF
curl --location --fail-with-body \
  "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
  --output "helm.tar.gz"

tar --extract --file "helm.tar.gz"

install --owner nobody --group nogroup --mode 0755 linux-amd64/helm /usr/local/bin/helm

rm --force --recursive linux-amd64 helm.tar.gz
EOF

# Cloud Platform CLI
RUN <<EOF
curl --location --fail-with-body \
  "https://github.com/ministryofjustice/cloud-platform-cli/releases/download/${CLOUD_PLATFORM_CLI_VERSION}/cloud-platform-cli_${CLOUD_PLATFORM_CLI_VERSION}_linux_amd64.tar.gz" \
  --output "cloud-platform-cli.tar.gz"

tar --extract --file cloud-platform-cli.tar.gz

install --owner nobody --group nogroup --mode 0755 cloud-platform /usr/local/bin/cloud-platform

rm --force --recursive cloud-platform LICENSE README.md completions cloud-platform-cli.tar.gz
EOF

# Microsoft SQL ODBC and Tools
RUN <<EOF
curl --location --fail-with-body \
  "https://packages.microsoft.com/keys/microsoft.asc" \
  --output microsoft.asc

cat microsoft.asc | gpg --dearmor --output microsoft-prod.gpg

install -D --owner root --group root --mode 644 microsoft-prod.gpg /usr/share/keyrings/microsoft-prod.gpg

echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/ubuntu/24.04/prod noble main" > /etc/apt/sources.list.d/mssql-release.list

apt-get update --yes

ACCEPT_EULA=Y apt-get install --yes \
  "msodbcsql18=${MICROSOFT_SQL_ODBC_VERSION}" \
  "mssql-tools18=${MICROSOFT_SQL_TOOLS_VERSION}"

apt-get clean --yes

rm --force --recursive /var/lib/apt/lists/* microsoft.asc microsoft-prod.gpg
EOF

# uv
RUN <<EOF
curl --location --fail-with-body \
  "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz" \
  --output uv.tar.gz

tar --extract --file uv.tar.gz

install --owner nobody --group nogroup --mode 0755 uv-x86_64-unknown-linux-gnu/uv /usr/local/bin/uv

install --owner nobody --group nogroup --mode 0755 uv-x86_64-unknown-linux-gnu/uvx /usr/local/bin/uvx

rm --force --recursive uv.tar.gz uv-x86_64-unknown-linux-gnu
EOF

USER ${CONTAINER_USER}
WORKDIR /home/${CONTAINER_USER}
