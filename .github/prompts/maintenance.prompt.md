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

### APT metadata preflight and failure handling

Complete this preflight before editing `Dockerfile` or the test file. APT can return exit code 0 while reporting that one or more indexes failed to download, which leaves `apt-cache policy` showing only installed versions. Do not treat that output as a successful candidate check.

- Run every `apt-get update` in these instructions with `-o APT::Update::Error-Mode=any` and do not redirect its output. Treat any fetch, signature, or index warning as a failed check, even if the command exits successfully.
- Run `apt-cache policy` only after a successful update and confirm each required package has a real candidate, not `(none)` or an installed version from stale local metadata.
- If a disposable container cannot reach a repository, retry once with Docker host networking where supported and pass through any configured `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` environment variables. If needed, try a reachable official mirror by changing sources only inside the disposable container; never alter the Dockerfile's configured repositories just to make the probe work.
- Derive the Ubuntu version and codename from `/etc/os-release` in the exact base image. Third-party repository URLs used for candidate checks must match that image; do not use hard-coded Ubuntu codenames or versions from the examples below.
- If base or third-party APT metadata still cannot be retrieved and validated, stop before changing files, committing, pushing, or opening a pull request. Report which repositories failed and the network error. Do not infer versions from installed packages, stale indexes, unrelated mirrors, or memory.

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

**Use one APT probe container for Steps 3 and 4.** Do not run separate `docker run --rm --platform linux/amd64 "$IMAGE"` commands for base packages, Python, R, GitHub CLI, Corretto, Node.js, NVIDIA CUDA, or Microsoft SQL. Start the container once, add every required third-party repository once, run the package metadata refresh once after all repositories are configured, and read every candidate from that same shell session's output. This matters most when the host architecture is not `linux/amd64`, since each separate container invocation incurs emulation startup and repository download overhead. The .NET SDK itself is not installed from APT in this `Dockerfile` (it is a direct binary download handled separately in Step 4) — only its `DOTNET_ICU_PACKAGE` runtime dependency is checked via APT, and that check is included in the consolidated probe below.

- Read the list of pinned packages from the first `apt-get install` block in `Dockerfile` (after the "Base Configuration" comment). Use exactly that set of packages; do not add or remove any.

Derive the exact Ubuntu version/codename from the base image, then run the single consolidated probe:

```bash
UBUNTU_VERSION="$(docker run --rm --platform linux/amd64 "$IMAGE" bash -c '. /etc/os-release && printf "%s" "$VERSION_ID"')"
UBUNTU_CODENAME="$(docker run --rm --platform linux/amd64 "$IMAGE" bash -c '. /etc/os-release && printf "%s" "$VERSION_CODENAME"')"
CUDA_REPO_VERSION="$(printf '%s' "$UBUNTU_VERSION" | tr -d '.')"
CURRENT_PYTHON_VERSION="$(grep -oP 'python\K3\.\d+' Dockerfile | head -1)"
CURRENT_JAVA_VERSION="$(grep -oP 'java-\K\d+(?=-amazon-corretto)' Dockerfile | head -1)"
CURRENT_NODE_MAJOR="$(grep -oP 'setup_\K\d+(?=\.x)' Dockerfile | head -1)"
CURRENT_CUDA_MAJOR_MINOR="$(grep -oP 'cuda-cudart-\K\d+-\d+' Dockerfile | head -1)"
CURRENT_SQL_MAJOR="$(grep -oP 'msodbcsql\K\d+' Dockerfile | head -1)"
CURRENT_ODBC_VERSION="$(grep -oP 'MICROSOFT_SQL_ODBC_VERSION="\K[^"]+' Dockerfile)"
CURRENT_TOOLS_VERSION="$(grep -oP 'MICROSOFT_SQL_TOOLS_VERSION="\K[^"]+' Dockerfile)"
DOTNET_ICU_PACKAGE="$(grep -oP 'DOTNET_ICU_PACKAGE="\K[^"]+' Dockerfile)"

docker run --rm --platform linux/amd64 "$IMAGE" bash -c "
set -euo pipefail
apt-get -o APT::Update::Error-Mode=any update --yes
apt-get install --yes curl gpg ca-certificates lsb-release

# Configure every third-party repository once, in this one container.
curl --location --fail-with-body 'https://apt.corretto.aws/corretto.key' -o corretto.key
cat corretto.key | gpg --dearmor -o corretto-keyring.gpg
install -D --mode 644 corretto-keyring.gpg /etc/apt/keyrings/corretto-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main' > /etc/apt/sources.list.d/corretto.list

curl --location --fail-with-body 'https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc' -o marutter_pubkey.asc
cat marutter_pubkey.asc | gpg --dearmor -o marutter_pubkey.gpg
install -D --mode 644 marutter_pubkey.gpg /etc/apt/keyrings/marutter_pubkey.gpg
echo 'deb [signed-by=/etc/apt/keyrings/marutter_pubkey.gpg] https://cloud.r-project.org/bin/linux/ubuntu ${UBUNTU_CODENAME}-cran40/' > /etc/apt/sources.list.d/cran.list

curl --location --fail-with-body 'https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${CUDA_REPO_VERSION}/x86_64/3bf863cc.pub' -o 3bf863cc.pub
cat 3bf863cc.pub | gpg --dearmor -o nvidia.gpg
install -D --mode 644 nvidia.gpg /etc/apt/keyrings/nvidia.gpg
echo 'deb [signed-by=/etc/apt/keyrings/nvidia.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${CUDA_REPO_VERSION}/x86_64 /' > /etc/apt/sources.list.d/cuda.list

curl --location --fail-with-body 'https://packages.microsoft.com/keys/microsoft.asc' -o microsoft.asc
cat microsoft.asc | gpg --dearmor -o microsoft-prod.gpg
install -D --mode 644 microsoft-prod.gpg /usr/share/keyrings/microsoft-prod.gpg
echo 'deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/ubuntu/${UBUNTU_VERSION}/prod ${UBUNTU_CODENAME} main' > /etc/apt/sources.list.d/mssql-release.list

curl --location --fail-with-body 'https://cli.github.com/packages/githubcli-archive-keyring.gpg' -o githubcli-archive-keyring.gpg
install -D --mode 644 githubcli-archive-keyring.gpg /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' > /etc/apt/sources.list.d/github-cli.list

curl --location --fail-with-body 'https://deb.nodesource.com/setup_${CURRENT_NODE_MAJOR}.x' -o node.sh
bash node.sh

# Refresh once, only after every repository above has been added.
apt-get -o APT::Update::Error-Mode=any update --yes

echo '=== Base package candidates ==='
apt-cache policy apt-transport-https ca-certificates curl git ffmpeg gzip jq mandoc less vim unixodbc unzip zstd libcurl4t64 libcurl3t64-gnutls libcurl4-openssl-dev python${CURRENT_PYTHON_VERSION} python3-pip

echo '=== Latest available Python (any minor version) ==='
apt-cache search --names-only '^python3\.[0-9]+\$' | sort -V

echo '=== R and GitHub CLI candidates ==='
apt-cache policy r-base r-base-core r-recommended gh

echo '=== .NET ICU runtime candidate ==='
apt-cache policy ${DOTNET_ICU_PACKAGE}

echo \"=== Current Java version (${CURRENT_JAVA_VERSION}) ===\"
JAVA_CANDIDATE_CURRENT=\$(apt-cache policy java-${CURRENT_JAVA_VERSION}-amazon-corretto-jdk | grep Candidate | awk '{print \$2}')
echo \"java-${CURRENT_JAVA_VERSION}-amazon-corretto-jdk: \$JAVA_CANDIDATE_CURRENT\"
echo '=== Latest available Java (any major) ==='
LATEST_JAVA_PKG=\$(apt-cache search --names-only '^java-[0-9]+-amazon-corretto-jdk\$' | grep -oP 'java-\K\d+' | sort -n | tail -1)
if [ -n \"\$LATEST_JAVA_PKG\" ] && [ \"\$LATEST_JAVA_PKG\" != \"${CURRENT_JAVA_VERSION}\" ]; then
  JAVA_CANDIDATE_LATEST=\$(apt-cache policy java-\${LATEST_JAVA_PKG}-amazon-corretto-jdk | grep Candidate | awk '{print \$2}')
  echo \"java-\${LATEST_JAVA_PKG}-amazon-corretto-jdk: \$JAVA_CANDIDATE_LATEST\"
  echo \"UPGRADE_TO_JAVA=\$LATEST_JAVA_PKG\"
fi

echo \"=== Node.js (from ${CURRENT_NODE_MAJOR}.x) ===\"
apt-cache policy nodejs

echo \"=== Current CUDA version (${CURRENT_CUDA_MAJOR_MINOR}) ===\"
CUDART_CANDIDATE_CURRENT=\$(apt-cache policy cuda-cudart-${CURRENT_CUDA_MAJOR_MINOR} | grep Candidate | awk '{print \$2}')
COMPAT_CANDIDATE_CURRENT=\$(apt-cache policy cuda-compat-${CURRENT_CUDA_MAJOR_MINOR} | grep Candidate | awk '{print \$2}')
echo \"cuda-cudart-${CURRENT_CUDA_MAJOR_MINOR}: \$CUDART_CANDIDATE_CURRENT\"
echo \"cuda-compat-${CURRENT_CUDA_MAJOR_MINOR}: \$COMPAT_CANDIDATE_CURRENT\"
echo '=== Latest available CUDA (any version) ==='
LATEST_CUDA_PKG=\$(apt-cache search --names-only '^cuda-cudart-[0-9]+-[0-9]+\$' | grep -oP 'cuda-cudart-\K\d+-\d+' | sort -V | tail -1)
if [ -n \"\$LATEST_CUDA_PKG\" ] && [ \"\$LATEST_CUDA_PKG\" != \"${CURRENT_CUDA_MAJOR_MINOR}\" ]; then
  CUDART_CANDIDATE_LATEST=\$(apt-cache policy cuda-cudart-\$LATEST_CUDA_PKG | grep Candidate | awk '{print \$2}')
  COMPAT_CANDIDATE_LATEST=\$(apt-cache policy cuda-compat-\$LATEST_CUDA_PKG | grep Candidate | awk '{print \$2}')
  echo \"cuda-cudart-\$LATEST_CUDA_PKG: \$CUDART_CANDIDATE_LATEST\"
  echo \"cuda-compat-\$LATEST_CUDA_PKG: \$COMPAT_CANDIDATE_LATEST\"
  echo \"UPGRADE_TO_CUDA=\$LATEST_CUDA_PKG\"
fi

echo \"=== Current Microsoft SQL major version (${CURRENT_SQL_MAJOR}) ===\"
ODBC_CANDIDATE_CURRENT=\$(apt-cache policy msodbcsql${CURRENT_SQL_MAJOR} | grep Candidate | awk '{print \$2}')
TOOLS_CANDIDATE_CURRENT=\$(apt-cache policy mssql-tools${CURRENT_SQL_MAJOR} | grep Candidate | awk '{print \$2}')
echo \"msodbcsql${CURRENT_SQL_MAJOR}: \$ODBC_CANDIDATE_CURRENT\"
echo \"mssql-tools${CURRENT_SQL_MAJOR}: \$TOOLS_CANDIDATE_CURRENT\"
if [ \"\$ODBC_CANDIDATE_CURRENT\" = \"${CURRENT_ODBC_VERSION}\" ] && [ \"\$TOOLS_CANDIDATE_CURRENT\" = \"${CURRENT_TOOLS_VERSION}\" ]; then
  echo 'Already on latest for current major version, checking for newer major versions...'
  LATEST_ODBC_PKG=\$(apt-cache search --names-only '^msodbcsql[0-9]+\$' | sort -V | tail -1 | awk '{print \$1}')
  if [ -n \"\$LATEST_ODBC_PKG\" ]; then
    LATEST_MAJOR=\$(echo \$LATEST_ODBC_PKG | grep -oP 'msodbcsql\K\d+')
    ODBC_CANDIDATE_LATEST=\$(apt-cache policy \$LATEST_ODBC_PKG | grep Candidate | awk '{print \$2}')
    TOOLS_CANDIDATE_LATEST=\$(apt-cache policy mssql-tools\${LATEST_MAJOR} | grep Candidate | awk '{print \$2}')
    echo \"\$LATEST_ODBC_PKG: \$ODBC_CANDIDATE_LATEST\"
    echo \"mssql-tools\${LATEST_MAJOR}: \$TOOLS_CANDIDATE_LATEST\"
    echo \"UPGRADE_TO_MAJOR=\$LATEST_MAJOR\"
  fi
fi
"
```

Use the output from this single probe for every APT-based package decision in Steps 3 and 4. Do not start another container to re-check any of these packages.

- Check the `=== Base package candidates ===` output for the candidate versions.
- **Python**: If `=== Latest available Python (any minor version) ===` lists a minor version newer than `${CURRENT_PYTHON_VERSION}`, note this as a potential upgrade in the PR description. Only update the pinned `python3.X`/`python3-pip` packages if the new minor version is stable and tested.
- **For other base packages**: Update each pinned version in `Dockerfile` to the reported candidate.

### 4. Update third-party APT package versions

Use the candidate output from the single consolidated probe in Step 3. Do not start another container or repeat repository setup here.

Update the relevant `ENV` variables and `apt-get install` version pins in `Dockerfile`:

- `R_VERSION` → `r-base`/`r-base-core`/`r-recommended` candidate
- `GITHUB_CLI_VERSION` → `gh` candidate

**Java/Amazon Corretto**: Use the `JAVA_CANDIDATE_CURRENT`/`UPGRADE_TO_JAVA` output from the consolidated probe.

- Update `CORRETTO_VERSION` to `JAVA_CANDIDATE_CURRENT`.
- If `UPGRADE_TO_JAVA` was printed, update the `java-{N}-amazon-corretto-jdk` package name in the Dockerfile to that major and note this as a major version upgrade for the PR description.

**.NET SDK**: Use the official .NET release metadata for the current SDK channel. The Ubuntu apt package may lag behind the upstream security-fixed SDK, so do not use its candidate as the source of truth.

```bash
CURRENT_DOTNET_CHANNEL="$(grep -oP 'DOTNET_SDK_VERSION="\K\d+\.\d+' Dockerfile | head -1)"

curl -fsSL "https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/${CURRENT_DOTNET_CHANNEL}/releases.json" |
  jq -r '.releases[0] as $release | $release.sdk.files[] | select(.rid == "linux-x64" and .name == "dotnet-sdk-linux-x64.tar.gz") | [$release.sdk.version, .url, .hash] | @tsv'
```

Update `DOTNET_SDK_VERSION` to the SDK version in the release metadata and `DOTNET_SDK_SHA512` to that Linux x64 archive's `hash`. The Dockerfile must verify the downloaded archive with `sha512sum --check` before extraction. Update the `dotnet` test expectation to the selected SDK version. Confirm the selected release includes the fixed runtime/library patch before updating.

Update `DOTNET_ICU_VERSION` to the candidate reported in the consolidated probe's `=== .NET ICU runtime candidate ===` output, without changing `DOTNET_ICU_PACKAGE` unless the base image's ICU ABI requires a different package.

**Node.js**: Use the `nodejs` candidate from the consolidated probe (installed from `setup_${CURRENT_NODE_MAJOR}.x`) together with the live Node.js release API for LTS-major comparison:

```bash
LATEST_NODE_VERSION="$(curl -fsSL https://nodejs.org/dist/index.json | jq -r '[.[] | select(.lts != false)][0].version | ltrimstr("v")')"
LATEST_NODE_MAJOR="${LATEST_NODE_VERSION%%.*}"
echo "Latest upstream Node.js LTS: ${LATEST_NODE_VERSION}"
```

Set `NODE_LTS_VERSION` to the numeric version prefix of the `nodejs` candidate from the consolidated probe (for example, candidate `24.21.0-1nodesource1` means `NODE_LTS_VERSION="24.21.0"`). If `LATEST_NODE_MAJOR` is newer than `CURRENT_NODE_MAJOR`, re-run only the Node.js portion of the consolidated probe (repository setup against `setup_${LATEST_NODE_MAJOR}.x`, refresh, then `apt-cache policy nodejs`) to confirm a concrete candidate exists before pinning it. Do not pin a newer version reported by nodejs.org until it is available as a concrete candidate from the configured NodeSource repository. Update the `node` test expectation to match the installed candidate.

**NVIDIA CUDA**: Use the `CUDART_CANDIDATE_CURRENT`/`COMPAT_CANDIDATE_CURRENT`/`UPGRADE_TO_CUDA` output from the consolidated probe.

- Update `NVIDIA_CUDA_CUDART_VERSION` to `CUDART_CANDIDATE_CURRENT` and `NVIDIA_CUDA_COMPAT_VERSION` to `COMPAT_CANDIDATE_CURRENT`.
- If `UPGRADE_TO_CUDA` was printed, update `CUDA_VERSION`, `NVIDIA_CUDA_CUDART_VERSION`, `NVIDIA_CUDA_COMPAT_VERSION`, and the `cuda-cudart-*`/`cuda-compat-*` package names in the Dockerfile to the new major.minor, and note this as a version upgrade for the PR description.

**Microsoft SQL ODBC and Tools**: Use the `ODBC_CANDIDATE_CURRENT`/`TOOLS_CANDIDATE_CURRENT`/`UPGRADE_TO_MAJOR` output from the consolidated probe to determine the upgrade path:

- **If the candidate versions for the current major version are newer than what's in the Dockerfile**: Update `MICROSOFT_SQL_ODBC_VERSION` and `MICROSOFT_SQL_TOOLS_VERSION` to those versions (patch/minor upgrade within same major version).
- **If `UPGRADE_TO_MAJOR` was printed** (already on the latest for the current major, and a newer major is available):
  - Update the Dockerfile to use the new major version package names (e.g., `msodbcsql18` → `msodbcsql19`)
  - Update `MICROSOFT_SQL_ODBC_VERSION` and `MICROSOFT_SQL_TOOLS_VERSION` to the new versions
  - Update the PATH environment variable (e.g., `/opt/mssql-tools18/bin` → `/opt/mssql-tools19/bin`)
  - Note this is a major version upgrade for the PR description
- **If already on the absolute latest version**: No updates needed for Microsoft SQL packages.

Analyse the output from all package checks above and determine upgrade paths:

- **For Java/Corretto**: If a newer major version is available (e.g., Java 22 or 23 when using 21), update the package name in the Dockerfile and note this as a major version upgrade for the PR description.
- **For .NET SDK**: If a newer major version is available (e.g., 9.0 when using 8.0), update the Dockerfile and note this as a major version upgrade for the PR description.
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
| .NET SDK                   | `<old>` | `<new>` |
| .NET ICU runtime           | `<old>` | `<new>` |
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
- Official SDK archive version and SHA512 updated
- ICU runtime package/version pin updated if required
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
