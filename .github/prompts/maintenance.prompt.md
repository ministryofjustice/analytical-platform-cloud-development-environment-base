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

```bash
docker run --rm --platform linux/amd64 "$IMAGE" \
  bash -c "apt-get update && apt-cache policy apt-transport-https ca-certificates curl git ffmpeg gzip jq mandoc less python3.12 python3-pip vim unixodbc unzip zstd"
```

- Update each pinned version in `Dockerfile` to the reported candidate, preserving every package currently listed.

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
  apt-cache policy java-21-amazon-corretto-jdk r-base dotnet-sdk-8.0 cuda-cudart-13-3 cuda-compat-13-3 msodbcsql18 mssql-tools18 gh nodejs"
```

Update the relevant `ENV` variables and `apt-get install` version pins in `Dockerfile`:

- `CORRETTO_VERSION` → `java-21-amazon-corretto-jdk` candidate
- `R_VERSION` → `r-base` candidate
- `DOTNET_SDK_VERSION` → `dotnet-sdk-8.0` candidate
- `NVIDIA_CUDA_CUDART_VERSION` → `cuda-cudart-13-3` candidate
- `NVIDIA_CUDA_COMPAT_VERSION` → `cuda-compat-13-3` candidate
- `MICROSOFT_SQL_ODBC_VERSION` → `msodbcsql18` candidate
- `MICROSOFT_SQL_TOOLS_VERSION` → `mssql-tools18` candidate
- `GITHUB_CLI_VERSION` → `gh` candidate
- `NODE_LTS_VERSION` → `nodejs` candidate (strip the `-1nodesource1` suffix)

**Important**: For NVIDIA CUDA, also check if there is a newer CUDA minor or major version available by inspecting the [NVIDIA CUDA repository](https://gitlab.com/nvidia/container-images/cuda/-/tree/master/dist). If a newer CUDA version is available:
1. Update `CUDA_VERSION`
2. Update `NVIDIA_CUDA_CUDART_VERSION` and `NVIDIA_CUDA_COMPAT_VERSION` to match the new CUDA version
3. Update package names if the CUDA apt package suffix changes (e.g., from `cuda-cudart-13-3` to `cuda-cudart-14-0`)

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
| `MICROSOFT_SQL_ODBC_VERSION` | msodbcsql      | `/opt/microsoft/msodbcsql18/lib64/libmsodbcsql-X.Y.so.Z.W` (file path) |
| `MICROSOFT_SQL_TOOLS_VERSION`| sqlcmd         | Verify actual output format from `sqlcmd -?`                            |

For NVIDIA CUDA `fileExistenceTests`, update paths if the CUDA major version changes (e.g., `/usr/local/cuda/lib64/libcudart.so.13` → `/usr/local/cuda/lib64/libcudart.so.14`).

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
