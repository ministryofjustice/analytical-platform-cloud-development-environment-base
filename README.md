# Analyical Platform Cloud Development Environment Base

[![Ministry of Justice Repository Compliance Badge](https://github-community.service.justice.gov.uk/repository-standards/api/analytical-platform-cloud-development-environment-base/badge)](https://github-community.service.justice.gov.uk/repository-standards/analytical-platform-cloud-development-environment-base)

[![Open in Dev Container](https://raw.githubusercontent.com/ministryofjustice/.devcontainer/refs/heads/main/contrib/badge.svg)](https://vscode.dev/redirect?url=vscode://ms-vscode-remote.remote-containers/cloneInVolume?url=https://github.com/ministryofjustice/analytical-platform-cloud-development-environment-base)

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/ministryofjustice/analytical-platform-cloud-development-environment-base)

This repository contains the code for building the base image used by Analytical Platform's Cloud Development Environments

## Features

This image is built on Ubuntu 24.04 LTS and includes the following software:

- [Python 3.12](https://www.python.org/downloads/release/python-3123/)

- [AWS CLI](https://aws.amazon.com/cli/)

- [AWS SSO CLI](https://synfinatic.github.io/aws-sso-cli/v1.17.0/)

- [Miniconda](https://docs.anaconda.com/miniconda/)

- [Node.js LTS](https://nodejs.org/en)

- [Amazon Corretto](https://aws.amazon.com/corretto)

- [.NET SDK](https://learn.microsoft.com/en-us/dotnet/core/sdk)

- [R](https://www.r-project.org/about.html)

- [Ollama](https://ollama.com/)

- [NVIDIA CUDA drivers](https://developer.nvidia.com/cuda-faq)

- [Kubernetes CLI](https://kubernetes.io/docs/reference/kubectl/)

- [Helm](https://helm.sh/)

- [Cloud Platform CLI](https://github.com/ministryofjustice/cloud-platform-cli)

- [Microsoft ODBC driver for SQL Server](https://learn.microsoft.com/en-us/sql/connect/odbc/microsoft-odbc-driver-for-sql-server)

- [nbstripout](https://github.com/kynan/nbstripout)

- [uv](https://github.com/astral-sh/uv)

## Running Locally

### Build

```bash
make build
```

### Test

```bash
make test
```

### Run

```bash
make run
```

## Managing Software Versions

### Ubuntu

Dependabot is configured to do this in [`.github/dependabot.yml`](.github/dependabot.yml), but if you need to get the digest, do the following

```bash
docker pull --platform linux/amd64 public.ecr.aws/ubuntu/ubuntu:24.04

docker image inspect --format='{{ index .RepoDigests 0 }}' public.ecr.aws/ubuntu/ubuntu:24.04
```

### Base APT Packages

The latest versions of the APT packages are managed by [Renovate](https://docs.renovatebot.com/) via the [Renovate `deb` data source](https://docs.renovatebot.com/modules/datasource/deb/) which matches packages through `regex` (regular expression) matching the `# renovate` comments in the [Dockerfile](./Dockerfile).
The [Renovate config](./.github/renovate.json) also disables organisation-level settings for Renovate, so it can compliment rather than conflict with Dependabot.

If you need to manually get latest versions of the APT packages, they can be obtained by running the following

```bash
docker run -it --rm --platform linux/amd64 public.ecr.aws/ubuntu/ubuntu:24.04

apt-get update

apt-cache policy ${PACKAGE} # for example curl, git or gpg
```

### AWS CLI

Releases for AWS CLI are provided on [GitHub](https://raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst)

### AWS SSO CLI

Releases for AWS SSO CLI are provided on [GitHub](https://github.com/synfinatic/aws-sso-cli/releases)

### Miniconda

Releases for Miniconda are provided on [anaconda.com](https://www.anaconda.com/docs/getting-started/miniconda/release-notes), from there we can use [repo.anaconda.com](https://repo.anaconda.com/miniconda/) to determine the artefact name and SHA256 based on a version. We currently use `py312`, `Linux` and `x86_64`variant.

### Node.js

Releases for Node.js LTS are provided on [nodejs.org](https://nodejs.org/en)

### Amazon Corretto

The last version of Amazon Corretto can be obtained by running:

```bash
docker run -it --rm --platform linux/amd64 public.ecr.aws/ubuntu/ubuntu:24.04

apt-get update

apt-get install --yes curl gpg

curl --location --fail-with-body \
  "https://apt.corretto.aws/corretto.key" \
  --output corretto.key

cat corretto.key | gpg --dearmor --output corretto-keyring.gpg

install -D --owner root --group root --mode 644 corretto-keyring.gpg /etc/apt/keyrings/corretto-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main" > /etc/apt/sources.list.d/corretto.list

apt-get update --yes

apt-cache policy java-21-amazon-corretto-jdk
```

### .NET SDK

The latest version of .NET SDK can be obtained by running:

```bash
docker run -it --rm --platform linux/amd64 public.ecr.aws/ubuntu/ubuntu:24.04

apt-get update --yes

apt-cache policy dotnet-sdk-8.0
```

### R

The latest version of R can be obtained by running:

```bash
docker run -it --rm --platform linux/amd64 public.ecr.aws/ubuntu/ubuntu:24.04

apt-get update --yes

apt-get install --yes curl gpg

curl --location --fail-with-body \
  "https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc" \
  --output "marutter_pubkey.asc"

cat marutter_pubkey.asc | gpg --dearmor --output marutter_pubkey.gpg

install -D --owner root --group root --mode 644 marutter_pubkey.gpg /etc/apt/keyrings/marutter_pubkey.gpg

echo "deb [signed-by=/etc/apt/keyrings/marutter_pubkey.gpg] https://cloud.r-project.org/bin/linux/ubuntu noble-cran40/" > /etc/apt/sources.list.d/cran.list

apt-get update --yes

apt-cache policy r-base
```

### Ollama

Releases for Ollama are maintained on [GitHub](https://github.com/ollama/ollama/releases).

### NVIDIA CUDA

> [!TIP]
> Running the commands below is not enough to ensure that the latest version of NVIDIA CUDA is installed. Double check there is not a minor or major version increase by inspecting the contents of the [CUDA repository](https://gitlab.com/nvidia/container-images/cuda/-/tree/master/dist).

The latest version of NVIDIA can be obtained by running:

```bash
docker run -it --rm --platform linux/amd64 public.ecr.aws/ubuntu/ubuntu:24.04

apt-get update

apt-get install --yes curl gpg

curl --location --fail-with-body \
  "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/3bf863cc.pub" \
  --output "3bf863cc.pub"

cat 3bf863cc.pub | gpg --dearmor --output nvidia.gpg

install -D --owner root --group root --mode 644 nvidia.gpg /etc/apt/keyrings/nvidia.gpg

echo "deb [signed-by=/etc/apt/keyrings/nvidia.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64 /" > /etc/apt/sources.list.d/cuda.list

apt-get update --yes

apt-cache policy cuda-cudart-12-8

apt-cache policy cuda-compat-12-8
```

### Kubernetes CLI

We offer Kubernetes CLI as a way for users to connect to Cloud Platform, therefore the version needs to align with that they suggest in [their documentation](https://user-guide.cloud-platform.service.justice.gov.uk/documentation/getting-started/kubectl-config.html#installing-kubectl)

### Helm

Releases for Helm are maintained on [GitHub](https://github.com/helm/helm/releases).

### Cloud Platform CLI

Releases for Cloud Platform CLI are maintained on [GitHub](https://github.com/ministryofjustice/cloud-platform-cli/releases).

### Microsoft ODBC driver for SQL Server

The latest version of Microsoft ODBC driver for SQL Server can be obtained by running:

```bash
docker run -it --rm --platform linux/amd64 public.ecr.aws/ubuntu/ubuntu:24.04

apt-get update --yes

apt-get install --yes curl gpg

curl --location --fail-with-body \
  "https://packages.microsoft.com/keys/microsoft.asc" \
  --output microsoft.asc

cat microsoft.asc | gpg --dearmor --output microsoft-prod.gpg

install -D --owner root --group root --mode 644 microsoft-prod.gpg /usr/share/keyrings/microsoft-prod.gpg

echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/ubuntu/24.04/prod noble main" > /etc/apt/sources.list.d/mssql-release.list

apt-get update --yes

apt-cache policy msodbcsql18

apt-cache policy mssql-tools18
```

### nbstripout

Release for nbstripout are maintained on [GitHub](https://github.com/kynan/nbstripout/releases).

### uv

Release for uv are maintained on [GitHub](https://github.com/astral-sh/uv/releases).

## Maintenance

Maintenance of this component is scheduled in this [workflow](https://github.com/ministryofjustice/analytical-platform/blob/main/.github/workflows/schedule-issue-cloud-development-environment-base.yml), which generates a maintenance ticket as per this [example](https://github.com/ministryofjustice/analytical-platform/issues/5905).
