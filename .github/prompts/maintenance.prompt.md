---
description: "Update the Ubuntu base image digest, pinned APT package versions, third-party APT packages, GitHub-released binaries, Miniconda, kubectl, and test expectations in the Dockerfile and test files, then open a pull request"
tools:
  [
    "search/codebase",
    "search",
    "edit/editFiles",
    "execute/runInTerminal",
    "execute/getTerminalOutput",
  ]
---

# Maintenance

Perform maintenance on the `Dockerfile` and `test/container-structure-test.yml`. Update the base image digest, the pinned APT package versions, third-party APT packages, GitHub-released binaries, Miniconda, kubectl, and the corresponding test expectations together, and open a single pull request. Read the current base image, tag, and package list from the `Dockerfile`; do not assume a specific Ubuntu version or package set.

## Objective

In one pull request, for the base image and packages already declared in the `Dockerfile`:

1. Update the pinned base image digest to the latest published digest for the image and tag in the `FROM` line (for `linux/amd64`).
2. Refresh the pinned base APT package versions to the latest available for that base image, preserving the current package list.
3. Update third-party APT package versions (Corretto, R, NVIDIA CUDA, Microsoft SQL ODBC/Tools, GitHub CLI, Node.js) to the latest available versions.
4. Update GitHub-released binaries (AWS CLI, AWS SSO CLI, Cloud Platform CLI, Helm, Ollama, nbstripout, uv, git-lfs, GitHub Copilot CLI) to the latest versions.
5. Update Miniconda to the latest version with updated SHA256 hash.
6. Update kubectl to the latest patch version within the current minor version.
7. Update the test expectations in `test/container-structure-test.yml` to match the new versions.

Do not assume a specific Ubuntu version or package set. Always read the current values from the `Dockerfile`.

## Required Outcome

1. Create a single maintenance branch.
2. Update the Ubuntu base image digest in the `FROM` line.
3. Update the pinned base APT package versions.
4. Update the third-party APT package versions.
5. Update the GitHub-released binary versions.
6. Update Miniconda version and SHA256 hash.
7. Update kubectl to latest patch version.
8. Update the test file to reflect the new versions.
9. Commit the changes using Conventional Commits.
10. Push the branch and open a pull request with a clear title and description.

## Execution Steps

### 1. Create a maintenance branch

```bash
git checkout -b "chore/maintenance-dockerfile-$(date +%Y%m%d-%H%M%S)"
```

### 2. Update the base image digest

- Read the base image reference (`<image>:<tag>`) from the `FROM` line in `Dockerfile`. Use whatever image and tag are currently pinned; do not assume a specific Ubuntu version.
- Pull that exact image for `linux/amd64`.

```bash
IMAGE="$(grep -oP '(?<=^FROM )[^@[:space:]]+' Dockerfile)"
docker pull --platform linux/amd64 "$IMAGE"
```

- Retrieve the current repository digest.

```bash
docker image inspect --format='{{ index .RepoDigests 0 }}' "$IMAGE"
```

- Update the `@sha256:...` digest on the `FROM` line to the new value, keeping the image and tag unchanged.

### 3. Update the pinned base APT package versions

- Read the list of pinned packages from the first `apt-get install` block in `Dockerfile` (after "Base Configuration" comment). Use exactly that set of packages; do not add or remove any.
- Start a temporary container using the same base image and check the candidate versions for those packages.

**Python**: Use a two-stage checking process for python3.x packages:

```bash
# Extract current Python minor version from Dockerfile (e.g., 3.12 from python3.12)
CURRENT_PYTHON_VERSION="$(grep -oP 'python\K3\.\d+' Dockerfile | head -1)"

docker run --rm --platform linux/amd64 "$IMAGE" bash<<ENDSCRIPT
apt-get update -y >/dev/null 2>&1

# Check latest version for current Python minor version
echo "=== Current Python version (${CURRENT_PYTHON_VERSION}) ==="
PYTHON_CANDIDATE_CURRENT=\$(apt-cache policy python${CURRENT_PYTHON_VERSION} | grep Candidate | awk '{print \$2}')
PIP_CANDIDATE_CURRENT=\$(apt-cache policy python3-pip | grep Candidate | awk '{print \$2}')
echo "python${CURRENT_PYTHON_VERSION}: \$PYTHON_CANDIDATE_CURRENT"
echo "python3-pip: \$PIP_CANDIDATE_CURRENT"

# Check if newer Python minor version is available
echo "=== Latest available Python (any minor version) ==="
LATEST_PYTHON_PKG=\$(apt-cache search --names-only '^python3\.[0-9]+$' | grep -oP 'python\K3\.\d+' | sort -V | tail -1)

if [ -n "\$LATEST_PYTHON_PKG" ] && [ "\$LATEST_PYTHON_PKG" != "${CURRENT_PYTHON_VERSION}" ]; then
  PYTHON_CANDIDATE_LATEST=\$(apt-cache policy python\$LATEST_PYTHON_PKG | grep Candidate | awk '{print \$2}')
  echo "Latest Python minor version: \$LATEST_PYTHON_PKG"
  echo "python\$LATEST_PYTHON_PKG: \$PYTHON_CANDIDATE_LATEST"
  echo "UPGRADE_TO_PYTHON=\$LATEST_PYTHON_PKG"
fi
ENDSCRIPT
```

For other base packages without major versions in package names:

```bash
docker run --rm --platform linux/amd64 "$IMAGE" \
  bash -c "apt-get update && apt-cache policy apt-transport-https ca-certificates curl git ffmpeg gzip jq mandoc less vim unixodbc unzip zstd"
```

- Analyse the output and update packages:
  - **For Python**: If a newer minor version is available (e.g., 3.13 when using 3.12), note this as a major version upgrade for the PR description. Only update if the new version is stable and tested.
  - **For other packages**: Update each pinned version in `Dockerfile` to the reported candidate.

### 4. Update third-party APT package versions

Start a temporary container using the base image and add all third-party APT repositories, then check candidate versions:

```bash
docker run --rm --platform linux/amd64 "$IMAGE" \
  bash -c "apt-get update --yes && \
  apt-get install --yes curl gpg && \

  # Corretto
  curl -sL 'https://apt.corretto.aws/corretto.key' -o corretto.key && \
  cat corretto.key | gpg --dearmor -o corretto-keyring.gpg 2>/dev/null && \
  install -D -m 644 corretto-keyring.gpg /etc/apt/keyrings/corretto-keyring.gpg && \
  echo 'deb [signed-by=/etc/apt/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main' > /etc/apt/sources.list.d/corretto.list && \

  # R
  curl -sL 'https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc' -o marutter_pubkey.asc && \
  cat marutter_pubkey.asc | gpg --dearmor -o marutter_pubkey.gpg 2>/dev/null && \
  install -D -m 644 marutter_pubkey.gpg /etc/apt/keyrings/marutter_pubkey.gpg && \
  echo 'deb [signed-by=/etc/apt/keyrings/marutter_pubkey.gpg] https://cloud.r-project.org/bin/linux/ubuntu noble-cran40/' > /etc/apt/sources.list.d/cran.list && \

  # NVIDIA CUDA
  curl -sL 'https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/3bf863cc.pub' -o 3bf863cc.pub && \
  cat 3bf863cc.pub | gpg --dearmor -o nvidia.gpg 2>/dev/null && \
  install -D -m 644 nvidia.gpg /etc/apt/keyrings/nvidia.gpg && \
  echo 'deb [signed-by=/etc/apt/keyrings/nvidia.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64 /' > /etc/apt/sources.list.d/cuda.list && \

  # Microsoft
  curl -sL 'https://packages.microsoft.com/keys/microsoft.asc' -o microsoft.asc && \
  cat microsoft.asc | gpg --dearmor -o microsoft-prod.gpg 2>/dev/null && \
  install -D -m 644 microsoft-prod.gpg /usr/share/keyrings/microsoft-prod.gpg && \
  echo 'deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/ubuntu/24.04/prod noble main' > /etc/apt/sources.list.d/mssql-release.list && \

  # GitHub CLI
  curl -sL 'https://cli.github.com/packages/githubcli-archive-keyring.gpg' -o githubcli-archive-keyring.gpg && \
  install -D -m 644 githubcli-archive-keyring.gpg /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
  echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' > /etc/apt/sources.list.d/github-cli.list && \

  # Node.js
  curl -sL 'https://deb.nodesource.com/setup_24.x' -o node.sh && bash node.sh >/dev/null 2>&1 && \

  apt-get update --yes && \
  apt-cache policy r-base gh"
```

Update the relevant `ENV` variables and `apt-get install` version pins in `Dockerfile`:

- `R_VERSION` → `r-base` candidate
- `GITHUB_CLI_VERSION` → `gh` candidate

**Java/Amazon Corretto**: Use a two-stage checking process:

```bash
# Extract current Java major version from Dockerfile (e.g., 21 from java-21-amazon-corretto-jdk)
CURRENT_JAVA_VERSION="$(grep -oP 'java-\K\d+(?=-amazon-corretto)' Dockerfile | head -1)"

docker run --rm --platform linux/amd64 "$IMAGE" bash<<ENDSCRIPT
apt-get update -y >/dev/null 2>&1
apt-get install -y curl gpg >/dev/null 2>&1

curl -sL 'https://apt.corretto.aws/corretto.key' -o corretto.key
cat corretto.key | gpg --dearmor -o corretto-keyring.gpg 2>/dev/null
install -D -m 644 corretto-keyring.gpg /etc/apt/keyrings/corretto-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main' > /etc/apt/sources.list.d/corretto.list

apt-get update -y >/dev/null 2>&1

# Check current Java version
echo "=== Current Java version (${CURRENT_JAVA_VERSION}) ==="
JAVA_CANDIDATE_CURRENT=\$(apt-cache policy java-${CURRENT_JAVA_VERSION}-amazon-corretto-jdk | grep Candidate | awk '{print \$2}')
echo "java-${CURRENT_JAVA_VERSION}-amazon-corretto-jdk: \$JAVA_CANDIDATE_CURRENT"

# Check for newer Java versions
echo "=== Latest available Java (any version) ==="
LATEST_JAVA_PKG=\$(apt-cache search --names-only '^java-[0-9]+-amazon-corretto-jdk$' | grep -oP 'java-\K\d+' | sort -n | tail -1)

if [ -n "\$LATEST_JAVA_PKG" ] && [ "\$LATEST_JAVA_PKG" != "${CURRENT_JAVA_VERSION}" ]; then
  JAVA_CANDIDATE_LATEST=\$(apt-cache policy java-\${LATEST_JAVA_PKG}-amazon-corretto-jdk | grep Candidate | awk '{print \$2}')
  echo "Latest Java version: \$LATEST_JAVA_PKG"
  echo "java-\${LATEST_JAVA_PKG}-amazon-corretto-jdk: \$JAVA_CANDIDATE_LATEST"
  echo "UPGRADE_TO_JAVA=\$LATEST_JAVA_PKG"
fi
ENDSCRIPT
```

**.NET SDK**: Use a two-stage checking process:

```bash
# Extract current .NET major version from Dockerfile (e.g., 8.0 from dotnet-sdk-8.0)
CURRENT_DOTNET_VERSION="$(grep -oP 'dotnet-sdk-\K\d+\.\d+' Dockerfile | head -1)"

docker run --rm --platform linux/amd64 "$IMAGE" bash<<ENDSCRIPT
apt-get update -y >/dev/null 2>&1

# Check current .NET version
echo "=== Current .NET SDK version (${CURRENT_DOTNET_VERSION}) ==="
DOTNET_CANDIDATE_CURRENT=\$(apt-cache policy dotnet-sdk-${CURRENT_DOTNET_VERSION} | grep Candidate | awk '{print \$2}')
echo "dotnet-sdk-${CURRENT_DOTNET_VERSION}: \$DOTNET_CANDIDATE_CURRENT"

# Check for newer .NET versions
echo "=== Latest available .NET SDK (any version) ==="
LATEST_DOTNET_PKG=\$(apt-cache search --names-only '^dotnet-sdk-[0-9]+\.[0-9]+$' | grep -oP 'dotnet-sdk-\K\d+\.\d+' | sort -V | tail -1)

if [ -n "\$LATEST_DOTNET_PKG" ] && [ "\$LATEST_DOTNET_PKG" != "${CURRENT_DOTNET_VERSION}" ]; then
  DOTNET_CANDIDATE_LATEST=\$(apt-cache policy dotnet-sdk-\$LATEST_DOTNET_PKG | grep Candidate | awk '{print \$2}')
  echo "Latest .NET SDK version: \$LATEST_DOTNET_PKG"
  echo "dotnet-sdk-\$LATEST_DOTNET_PKG: \$DOTNET_CANDIDATE_LATEST"
  echo "UPGRADE_TO_DOTNET=\$LATEST_DOTNET_PKG"
fi
ENDSCRIPT
```

**Node.js**: Use a two-stage checking process:

```bash
# Extract current Node.js major version from Dockerfile (e.g., 24 from setup_24.x)
CURRENT_NODE_MAJOR="$(grep -oP 'setup_\K\d+(?=\.x)' Dockerfile | head -1)"

docker run --rm --platform linux/amd64 "$IMAGE" bash<<ENDSCRIPT
apt-get update -y >/dev/null 2>&1
apt-get install -y curl >/dev/null 2>&1

# Setup current Node.js repository
curl -sL "https://deb.nodesource.com/setup_${CURRENT_NODE_MAJOR}.x" -o node.sh
bash node.sh >/dev/null 2>&1
apt-get update -y >/dev/null 2>&1

echo "=== Current Node.js major version (${CURRENT_NODE_MAJOR}) ==="
NODE_CANDIDATE_CURRENT=\$(apt-cache policy nodejs | grep Candidate | awk '{print \$2}')
echo "nodejs (from ${CURRENT_NODE_MAJOR}.x): \$NODE_CANDIDATE_CURRENT"

# Check for newer Node.js LTS versions
echo "=== Latest Node.js LTS version ==="
LATEST_NODE_MAJOR=\$(curl -sL https://nodejs.org/dist/index.json | grep -oP '"version":"v\K\d+' | head -1)
echo "Latest Node.js major version: \$LATEST_NODE_MAJOR"

if [ -n "\$LATEST_NODE_MAJOR" ] && [ "\$LATEST_NODE_MAJOR" != "${CURRENT_NODE_MAJOR}" ]; then
  echo "UPGRADE_TO_NODE=\$LATEST_NODE_MAJOR"
fi
ENDSCRIPT
```

**NVIDIA CUDA**: Use a two-stage checking process:

```bash
# Extract current CUDA major.minor version from Dockerfile
CURRENT_CUDA_MAJOR_MINOR="$(grep -oP 'cuda-cudart-\K\d+-\d+' Dockerfile | head -1)"

docker run --rm --platform linux/amd64 "$IMAGE" bash<<ENDSCRIPT
apt-get update -y >/dev/null 2>&1
apt-get install -y curl gpg >/dev/null 2>&1

curl -sL 'https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/3bf863cc.pub' -o 3bf863cc.pub
cat 3bf863cc.pub | gpg --dearmor -o nvidia.gpg 2>/dev/null
install -D -m 644 nvidia.gpg /etc/apt/keyrings/nvidia.gpg
echo 'deb [signed-by=/etc/apt/keyrings/nvidia.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64 /' > /etc/apt/sources.list.d/cuda.list

apt-get update -y >/dev/null 2>&1

echo "=== Current CUDA version (${CURRENT_CUDA_MAJOR_MINOR}) ==="
CUDART_CANDIDATE_CURRENT=\$(apt-cache policy cuda-cudart-${CURRENT_CUDA_MAJOR_MINOR} | grep Candidate | awk '{print \$2}')
COMPAT_CANDIDATE_CURRENT=\$(apt-cache policy cuda-compat-${CURRENT_CUDA_MAJOR_MINOR} | grep Candidate | awk '{print \$2}')
echo "cuda-cudart-${CURRENT_CUDA_MAJOR_MINOR}: \$CUDART_CANDIDATE_CURRENT"
echo "cuda-compat-${CURRENT_CUDA_MAJOR_MINOR}: \$COMPAT_CANDIDATE_CURRENT"

# Check for newer CUDA versions
echo "=== Latest available CUDA (any version) ==="
LATEST_CUDA_PKG=\$(apt-cache search --names-only '^cuda-cudart-[0-9]+-[0-9]+$' | grep -oP 'cuda-cudart-\K\d+-\d+' | sort -V | tail -1)

if [ -n "\$LATEST_CUDA_PKG" ] && [ "\$LATEST_CUDA_PKG" != "${CURRENT_CUDA_MAJOR_MINOR}" ]; then
  CUDART_CANDIDATE_LATEST=\$(apt-cache policy cuda-cudart-\$LATEST_CUDA_PKG | grep Candidate | awk '{print \$2}')
  COMPAT_CANDIDATE_LATEST=\$(apt-cache policy cuda-compat-\$LATEST_CUDA_PKG | grep Candidate | awk '{print \$2}')
  echo "Latest CUDA version: \$LATEST_CUDA_PKG"
  echo "cuda-cudart-\$LATEST_CUDA_PKG: \$CUDART_CANDIDATE_LATEST"
  echo "cuda-compat-\$LATEST_CUDA_PKG: \$COMPAT_CANDIDATE_LATEST"
  echo "UPGRADE_TO_CUDA=\$LATEST_CUDA_PKG"
fi
ENDSCRIPT
```

**Microsoft SQL ODBC and Tools**: Update these packages using a two-stage checking process:

1. First, check for minor/patch updates within the current major version:

```bash
# Extract current major version from Dockerfile (e.g., 18 from msodbcsql18)
CURRENT_MAJOR_VERSION="$(grep -oP 'msodbcsql\K\d+' Dockerfile | head -1)"
CURRENT_ODBC_VERSION="$(grep -oP 'MICROSOFT_SQL_ODBC_VERSION="\K[^"]+' Dockerfile)"
CURRENT_TOOLS_VERSION="$(grep -oP 'MICROSOFT_SQL_TOOLS_VERSION="\K[^"]+' Dockerfile)"

docker run --rm --platform linux/amd64 "$IMAGE" bash<<ENDSCRIPT
apt-get update -y >/dev/null 2>&1
apt-get install -y curl gpg lsb-release >/dev/null 2>&1
curl -sL 'https://packages.microsoft.com/keys/microsoft.asc' | gpg --dearmor > /usr/share/keyrings/microsoft-prod.gpg 2>/dev/null
source /etc/os-release
CODENAME=\$(lsb_release -cs)
echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/ubuntu/\${VERSION_ID}/prod \${CODENAME} main" > /etc/apt/sources.list.d/mssql-release.list
apt-get update -y >/dev/null 2>&1

# Check latest version for current major version
echo "=== Current major version (${CURRENT_MAJOR_VERSION}) ==="
ODBC_CANDIDATE_CURRENT=\$(apt-cache policy msodbcsql${CURRENT_MAJOR_VERSION} | grep Candidate | awk '{print \$2}')
TOOLS_CANDIDATE_CURRENT=\$(apt-cache policy mssql-tools${CURRENT_MAJOR_VERSION} | grep Candidate | awk '{print \$2}')
echo "msodbcsql${CURRENT_MAJOR_VERSION}: \$ODBC_CANDIDATE_CURRENT"
echo "mssql-tools${CURRENT_MAJOR_VERSION}: \$TOOLS_CANDIDATE_CURRENT"

# Check if we're already on the latest for this major version
if [ "\$ODBC_CANDIDATE_CURRENT" = "${CURRENT_ODBC_VERSION}" ] && [ "\$TOOLS_CANDIDATE_CURRENT" = "${CURRENT_TOOLS_VERSION}" ]; then
  echo "Already on latest for major version ${CURRENT_MAJOR_VERSION}, checking for newer major versions..."

  # Find the latest available package (any major version)
  echo "=== Latest available (any version) ==="
  LATEST_ODBC_PKG=\$(apt-cache search --names-only '^msodbcsql[0-9]+$' | sort -V | tail -1 | awk '{print \$1}')
  LATEST_TOOLS_PKG=\$(apt-cache search --names-only '^mssql-tools[0-9]+$' | sort -V | tail -1 | awk '{print \$1}')

  if [ -n "\$LATEST_ODBC_PKG" ]; then
    LATEST_MAJOR=\$(echo \$LATEST_ODBC_PKG | grep -oP 'msodbcsql\K\d+')
    ODBC_CANDIDATE_LATEST=\$(apt-cache policy \$LATEST_ODBC_PKG | grep Candidate | awk '{print \$2}')
    TOOLS_CANDIDATE_LATEST=\$(apt-cache policy mssql-tools\${LATEST_MAJOR} | grep Candidate | awk '{print \$2}')

    echo "Latest package: \$LATEST_ODBC_PKG (major version \$LATEST_MAJOR)"
    echo "\$LATEST_ODBC_PKG: \$ODBC_CANDIDATE_LATEST"
    echo "mssql-tools\${LATEST_MAJOR}: \$TOOLS_CANDIDATE_LATEST"
    echo "UPGRADE_TO_MAJOR=\$LATEST_MAJOR"
  fi
fi
ENDSCRIPT
```

2. Analyse the output and determine the upgrade path:
   - **If the candidate versions for the current major version are newer than what's in the Dockerfile**: Update `MICROSOFT_SQL_ODBC_VERSION` and `MICROSOFT_SQL_TOOLS_VERSION` to those versions (patch/minor upgrade within same major version).
   - **If already on the latest for the current major version, and a newer major version exists**:
     - Update the Dockerfile to use the new major version package names (e.g., `msodbcsql18` → `msodbcsql19`)
     - Update `MICROSOFT_SQL_ODBC_VERSION` and `MICROSOFT_SQL_TOOLS_VERSION` to the new versions
     - Update the PATH environment variable (e.g., `/opt/mssql-tools18/bin` → `/opt/mssql-tools19/bin`)
     - Note this is a major version upgrade for the PR description
   - **If already on the absolute latest version**: No updates needed for Microsoft SQL packages.

3. Analyse the output from all package checks and determine upgrade paths:
   - **For Java/Corretto**: If a newer major version is available (e.g., Java 22 or 23 when using 21), update the package name in the Dockerfile and note this as a major version upgrade for the PR description.
   - **For .NET SDK**: If a newer major version is available (e.g., 9.0 when using 8.0), update the package name in the Dockerfile and note this as a major version upgrade for the PR description.
   - **For Node.js**: If a newer LTS major version is available (e.g., 26 when using 24), update the setup script URL and note this as a major version upgrade for the PR description.
   - **For NVIDIA CUDA**: If a newer version is available, update `CUDA_VERSION`, `NVIDIA_CUDA_CUDART_VERSION`, `NVIDIA_CUDA_COMPAT_VERSION`, and package names, and note this as a major version upgrade for the PR description.
   - **For Python**: If a newer minor version is available (e.g., 3.13 when using 3.12), this would be a significant upgrade. Note this in the PR but consider carefully whether to apply it (Python minor versions can have breaking changes).

### 5. Update GitHub-released binary versions

Check the latest release for each tool distributed via GitHub releases. Use the GitHub API to fetch the latest version:

```bash
# AWS CLI (uses tags, not releases; no 'v' prefix)
curl -s "https://api.github.com/repos/aws/aws-cli/tags?per_page=5" | jq -r '.[0].name'

# AWS SSO CLI
curl -s "https://api.github.com/repos/synfinatic/aws-sso-cli/releases/latest" | jq -r '.tag_name' | sed 's/^v//'

# Cloud Platform CLI
curl -s "https://api.github.com/repos/ministryofjustice/cloud-platform-cli/releases/latest" | jq -r '.tag_name' | sed 's/^v//'

# Helm
curl -s "https://api.github.com/repos/helm/helm/releases/latest" | jq -r '.tag_name' | sed 's/^v//'

# Ollama
curl -s "https://api.github.com/repos/ollama/ollama/releases/latest" | jq -r '.tag_name' | sed 's/^v//'

# nbstripout
curl -s "https://api.github.com/repos/kynan/nbstripout/releases/latest" | jq -r '.tag_name' | sed 's/^v//'

# uv
curl -s "https://api.github.com/repos/astral-sh/uv/releases/latest" | jq -r '.tag_name'

# git-lfs
curl -s "https://api.github.com/repos/git-lfs/git-lfs/releases/latest" | jq -r '.tag_name' | sed 's/^v//'

# GitHub Copilot CLI
curl -s "https://api.github.com/repos/github/copilot-cli/releases/latest" | jq -r '.tag_name' | sed 's/^v//'
```

Update the corresponding `ENV` variables in `Dockerfile`:

- `AWS_CLI_VERSION`
- `AWS_SSO_CLI_VERSION`
- `CLOUD_PLATFORM_CLI_VERSION`
- `HELM_VERSION`
- `OLLAMA_VERSION`
- `NBSTRIPOUT_VERSION`
- `UV_VERSION`
- `GIT_LFS_VERSION`
- `GITHUB_COPILOT_CLI_VERSION`

**Special case for git-lfs**: When updating `GIT_LFS_VERSION`, also update `GIT_LFS_VERSION_SHA`:

```bash
NEW_VERSION="<new-git-lfs-version>"
curl -sL "https://github.com/git-lfs/git-lfs/releases/download/v${NEW_VERSION}/git-lfs-linux-amd64-v${NEW_VERSION}.tar.gz" | sha256sum
```

Update both `GIT_LFS_VERSION` and `GIT_LFS_VERSION_SHA` in `Dockerfile`.

### 6. Update Miniconda version and SHA256

Check the latest Miniconda version:

```bash
curl -s "https://repo.anaconda.com/miniconda/" | grep -oP 'Miniconda3-py312_\K[0-9]+\.[0-9]+\.[0-9]+-[0-9]+' | sort -V | tail -1
```

If the version has changed, download the new installer and compute its SHA256:

```bash
NEW_VERSION="<new-miniconda-version>"
curl -sL "https://repo.anaconda.com/miniconda/Miniconda3-py312_${NEW_VERSION}-Linux-x86_64.sh" | sha256sum
```

Update both `MINICONDA_VERSION` and `MINICONDA_SHA256` in `Dockerfile`.

### 7. Update kubectl version

kubectl is pinned to align with Cloud Platform cluster versions. Only update to the latest **patch** version within the current minor version. Do not bump the minor version without explicit approval.

Extract the current minor version and check for the latest patch:

```bash
CURRENT_MINOR=$(grep KUBECTL_VERSION Dockerfile | grep -oP '\d+\.\d+')
curl -s "https://dl.k8s.io/release/stable-${CURRENT_MINOR}.txt"
```

Update `KUBECTL_VERSION` to the latest patch version (format: `X.Y.Z`).

**Note**: If a newer minor version is available, mention it in the PR description but do not update it automatically.

### 8. Update the test file

Update `test/container-structure-test.yml` to reflect the new versions. Each tool has a `commandTests` entry with an `expectedOutput` that must match the new version.

Key mappings between Dockerfile `ENV` variables and test expected outputs:

| Dockerfile ENV               | Test name      | Expected output format                                                  |
| ---------------------------- | -------------- | ----------------------------------------------------------------------- |
| `AWS_CLI_VERSION`            | aws            | `aws-cli/X.Y.Z`                                                         |
| `AWS_SSO_CLI_VERSION`        | aws-sso        | `AWS SSO CLI Version X.Y.Z`                                             |
| `OLLAMA_VERSION`             | ollama         | `X.Y.Z`                                                                 |
| `KUBECTL_VERSION`            | kubectl        | `Client Version: vX.Y.Z`                                                |
| `HELM_VERSION`               | helm           | `X.Y.Z`                                                                 |
| `CLOUD_PLATFORM_CLI_VERSION` | cloud-platform | `X.Y.Z`                                                                 |
| `NBSTRIPOUT_VERSION`         | nbstripout     | `X.Y.Z`                                                                 |
| `UV_VERSION`                 | uv             | `uv X.Y.Z`                                                              |
| `UV_VERSION`                 | uvx            | `uvx X.Y.Z`                                                             |
| `GIT_LFS_VERSION`            | git-lfs        | `git-lfs/X.Y.Z`                                                         |
| `GITHUB_CLI_VERSION`         | gh             | `gh version X.Y.Z`                                                      |
| `GITHUB_COPILOT_CLI_VERSION` | copilot        | `GitHub Copilot CLI X.Y.Z`                                              |
| `NODE_LTS_VERSION`           | node           | `vX.Y.Z`                                                                |
| `CORRETTO_VERSION`           | corretto       | `openjdk X.Y.Z` (extract major.minor.patch from version)               |
| `DOTNET_SDK_VERSION`         | dotnet         | `X.Y.Z` (numeric prefix before `-`)                                     |
| `R_VERSION`                  | r              | `R version X.Y.Z` (first 3 components)                                  |
| `MICROSOFT_SQL_ODBC_VERSION` | msodbcsql      | `/opt/microsoft/msodbcsql{MAJOR}/lib64/libmsodbcsql-X.Y.so.Z.W` (file path) |
| `MICROSOFT_SQL_TOOLS_VERSION`| sqlcmd         | `Version X.Y.ZZZZ.W Linux` (from `sqlcmd -?` output)                    |

For NVIDIA CUDA `fileExistenceTests`, update paths if the CUDA major version changes (e.g., `/usr/local/cuda/lib64/libcudart.so.13` → `/usr/local/cuda/lib64/libcudart.so.14`).

For Microsoft SQL ODBC `fileExistenceTests`, update the path if the major version was upgraded (e.g., `/opt/microsoft/msodbcsql18/lib64/libmsodbcsql-18.6.so.2.1` → `/opt/microsoft/msodbcsql19/lib64/libmsodbcsql-19.0.so.1.0`). The path format is `/opt/microsoft/msodbcsql{MAJOR}/lib64/libmsodbcsql-{MAJOR}.{MINOR}.so.{PATCH}.{BUILD}`.

### 9. Confirm no package list changes

Verify the `Dockerfile` still lists the same packages and the same image and tag as before. Only digest and versions should differ. Do not add or remove packages.

### 10. Commit and create pull request

Commit the changes to `Dockerfile` and `test/container-structure-test.yml` using [Conventional Commits](https://www.conventionalcommits.org/) (`build` type):

```bash
git add Dockerfile test/container-structure-test.yml
git commit -m "build: update base image digest, package versions, and test expectations"
```

Push the branch and create a pull request with the GitHub CLI:

```bash
BRANCH="$(git branch --show-current)"
git push -u origin "$BRANCH"
```

Write the PR description to a temporary file to avoid shell-escaping issues:

```bash
cat > /tmp/pr-body.md << 'EOF'
## Summary

Updates the `Dockerfile` build dependencies.

### Base image

- `<image>:<tag>` digest: `sha256:<old-sha256>` → `sha256:<new-sha256>` (image and tag unchanged)

### Base APT packages

Include this section only when one or more base APT package versions changed.

| Package            | Before  | After   |
| ------------------ | ------- | ------- |
| apt-transport-https | `<old>` | `<new>` |
| ca-certificates    | `<old>` | `<new>` |
| curl               | `<old>` | `<new>` |
| git                | `<old>` | `<new>` |
| ffmpeg             | `<old>` | `<new>` |
| gzip               | `<old>` | `<new>` |
| jq                 | `<old>` | `<new>` |
| mandoc             | `<old>` | `<new>` |
| less               | `<old>` | `<new>` |
| python3.12         | `<old>` | `<new>` |
| python3-pip        | `<old>` | `<new>` |
| vim                | `<old>` | `<new>` |
| unixodbc           | `<old>` | `<new>` |
| unzip              | `<old>` | `<new>` |
| zstd               | `<old>` | `<new>` |

If no base APT package versions changed, omit the entire `### Base APT packages` section and add a single line in `## Summary`: `Base APT package versions already up to date.`

### Third-party APT packages

Include this section only when one or more third-party APT package versions changed.

| Package                    | Before  | After   |
| -------------------------- | ------- | ------- |
| Amazon Corretto (JDK 21)   | `<old>` | `<new>` |
| R                          | `<old>` | `<new>` |
| .NET SDK 8.0               | `<old>` | `<new>` |
| NVIDIA CUDA                | `<old>` | `<new>` |
| NVIDIA CUDA cudart         | `<old>` | `<new>` |
| NVIDIA CUDA compat         | `<old>` | `<new>` |
| Microsoft SQL ODBC         | `<old>` | `<new>` |
| Microsoft SQL Tools        | `<old>` | `<new>` |
| GitHub CLI                 | `<old>` | `<new>` |
| Node.js LTS                | `<old>` | `<new>` |

If no third-party APT package versions changed, omit the entire `### Third-party APT packages` section and add a single line in `## Summary`: `Third-party APT package versions already up to date.`

### GitHub-released binaries

Include this section only when one or more binary versions changed.

| Package            | Before  | After   |
| ------------------ | ------- | ------- |
| AWS CLI            | `<old>` | `<new>` |
| AWS SSO CLI        | `<old>` | `<new>` |
| Cloud Platform CLI | `<old>` | `<new>` |
| Helm               | `<old>` | `<new>` |
| Ollama             | `<old>` | `<new>` |
| nbstripout         | `<old>` | `<new>` |
| uv                 | `<old>` | `<new>` |
| git-lfs            | `<old>` | `<new>` |
| GitHub Copilot CLI | `<old>` | `<new>` |

If no binary versions changed, omit the entire `### GitHub-released binaries` section and add a single line in `## Summary`: `GitHub-released binary versions already up to date.`

### Other packages

Include this section only when Miniconda or kubectl versions changed.

| Package   | Before  | After   |
| --------- | ------- | ------- |
| Miniconda | `<old>` | `<new>` |
| kubectl   | `<old>` | `<new>` |

If neither changed, omit the entire `### Other packages` section and add a single line in `## Summary`: `Miniconda and kubectl versions already up to date.`

**kubectl note**: If a newer minor version is available but not updated (only patch updated), mention it here: `kubectl minor version X.Y is available but not updated (requires cluster alignment).`

### ⚠️ Major Version Upgrades

Include this section only when one or more packages were upgraded to a new major version. Add relevant subsections below:

**Microsoft SQL ODBC and Tools** (if upgraded, e.g., from msodbcsql18 to msodbcsql19):

```markdown
⚠️ **Microsoft SQL ODBC and Tools** upgraded from version {OLD_MAJOR} to version {NEW_MAJOR}.

This upgrade was applied because no further updates are available for version {OLD_MAJOR}.

Major version upgrades may include breaking changes. The following changes were made:
- Package names updated: `msodbcsql{OLD_MAJOR}` → `msodbcsql{NEW_MAJOR}`, `mssql-tools{OLD_MAJOR}` → `mssql-tools{NEW_MAJOR}`
- PATH updated: `/opt/mssql-tools{OLD_MAJOR}/bin` → `/opt/mssql-tools{NEW_MAJOR}/bin`
- Test expectations updated in `test/container-structure-test.yml`
```

**Java/Amazon Corretto** (if upgraded, e.g., from Java 21 to Java 23):

```markdown
⚠️ **Java/Amazon Corretto** upgraded from version {OLD_MAJOR} to version {NEW_MAJOR}.

This upgrade was applied because no further updates are available for version {OLD_MAJOR}.

Major version upgrades may include breaking changes. The following changes were made:
- Package name updated: `java-{OLD_MAJOR}-amazon-corretto-jdk` → `java-{NEW_MAJOR}-amazon-corretto-jdk`
- Test expectations updated in `test/container-structure-test.yml`
```

**.NET SDK** (if upgraded, e.g., from 8.0 to 9.0):

```markdown
⚠️ **.NET SDK** upgraded from version {OLD_MAJOR} to version {NEW_MAJOR}.

This upgrade was applied because no further updates are available for version {OLD_MAJOR}.

Major version upgrades may include breaking changes. The following changes were made:
- Package name updated: `dotnet-sdk-{OLD_MAJOR}` → `dotnet-sdk-{NEW_MAJOR}`
- Test expectations updated in `test/container-structure-test.yml`
```

**Node.js** (if upgraded, e.g., from 24 to 26):

```markdown
⚠️ **Node.js** upgraded from version {OLD_MAJOR} to version {NEW_MAJOR}.

This upgrade was applied because a newer LTS version is available.

Major version upgrades may include breaking changes. The following changes were made:
- Repository setup script updated: `setup_{OLD_MAJOR}.x` → `setup_{NEW_MAJOR}.x`
- Test expectations updated in `test/container-structure-test.yml`
```

**NVIDIA CUDA** (if upgraded, e.g., from 13.3 to 14.0):

```markdown
⚠️ **NVIDIA CUDA** upgraded from version {OLD_VERSION} to version {NEW_VERSION}.

This upgrade was applied because a newer CUDA version is available.

Major version upgrades may include breaking changes. The following changes were made:
- `CUDA_VERSION` updated: `{OLD_VERSION}` → `{NEW_VERSION}`
- Package names updated: `cuda-cudart-{OLD_SUFFIX}` → `cuda-cudart-{NEW_SUFFIX}`, `cuda-compat-{OLD_SUFFIX}` → `cuda-compat-{NEW_SUFFIX}`
- Test file paths updated in `test/container-structure-test.yml`
```

**Python** (if upgraded, e.g., from 3.12 to 3.13):

```markdown
⚠️ **Python** upgrade available from version {OLD_VERSION} to version {NEW_VERSION}.

**This upgrade was NOT applied automatically** as Python minor version upgrades can introduce breaking changes and require careful testing.

To upgrade Python:
1. Update package name: `python{OLD_VERSION}` → `python{NEW_VERSION}`
2. Update test expectations in `test/container-structure-test.yml`
3. Test all Python-dependent functionality thoroughly
```

End the section with:

```markdown
Please review and test carefully before merging.
```

### Tests

Updated `test/container-structure-test.yml` to reflect the new version expectations.

Building and testing is handled by CI/CD.
EOF
```

Create the pull request:

```bash
gh pr create --base main --head "$BRANCH" --title "build: update base image digest, package versions, and test expectations" --body-file /tmp/pr-body.md
```

Report the URL of the created pull request.

## Guardrails

- Keep the base image repository and tag unchanged; derive them from the existing `FROM` line and only update the digest. Do not change the Ubuntu version.
- Keep platform assumption aligned to `linux/amd64`.
- Do not add or remove packages. Update exactly the packages already pinned in the `Dockerfile`.
- Keep all package installs pinned to explicit versions.
- Update kubectl only to the latest patch version within the current minor version. Do not bump the minor version automatically.
- Update Miniconda and git-lfs SHA256 hashes when versions change.
- Check NVIDIA CUDA for minor/major version updates beyond what apt-cache shows.
- Update the test file (`test/container-structure-test.yml`) to match all new versions in the `Dockerfile`.
- Deliver all updates in the same branch and pull request.
- Use [Conventional Commits](https://www.conventionalcommits.org/) for both the commit message and the PR title (use the `build` type).
- Wrap all SHA256 digest values in backticks in the PR description.
- Include tables in the PR description only for packages that actually changed; omit sections where nothing changed and add a summary note instead.
