# Automated Software Version Update

This issue was automatically created to check and update software versions in the Dockerfile.

## Task Description

Please check all software versions documented in the README.md and update the Dockerfile with the latest available versions.

## Components to Check

### APT-based packages (requires Docker commands):
- [ ] **Amazon Corretto** (Java 21) - Current: `ENV CORRETTO_VERSION`
- [ ] **.NET SDK 8.0** - Current: `ENV DOTNET_SDK_VERSION`
- [ ] **R** - Current: `ENV R_VERSION`
- [ ] **NVIDIA CUDA** (cuda-cudart-13-0 and cuda-compat-13-0) - Current: `ENV NVIDIA_CUDA_CUDART_VERSION` and `ENV NVIDIA_CUDA_COMPAT_VERSION`
- [ ] **Microsoft ODBC Driver for SQL Server** - Current: `ENV MICROSOFT_SQL_ODBC_VERSION` and `ENV MICROSOFT_SQL_TOOLS_VERSION`

### GitHub Releases:
- [ ] **AWS CLI** - Current: `ENV AWS_CLI_VERSION` - Check: https://github.com/aws/aws-cli/blob/v2/CHANGELOG.rst
- [ ] **AWS SSO CLI** - Current: `ENV AWS_SSO_CLI_VERSION` - Check: https://github.com/synfinatic/aws-sso-cli/releases
- [ ] **Ollama** - Current: `ENV OLLAMA_VERSION` - Check: https://github.com/ollama/ollama/releases
- [ ] **Helm** - Current: `ENV HELM_VERSION` - Check: https://github.com/helm/helm/releases
- [ ] **Cloud Platform CLI** - Current: `ENV CLOUD_PLATFORM_CLI_VERSION` - Check: https://github.com/ministryofjustice/cloud-platform-cli/releases
- [ ] **nbstripout** - Current: `ENV NBSTRIPOUT_VERSION` - Check: https://github.com/kynan/nbstripout/releases
- [ ] **uv** - Current: `ENV UV_VERSION` - Check: https://github.com/astral-sh/uv/releases
- [ ] **git-lfs** - Current: `ENV GIT_LFS_VERSION` - Check: https://github.com/git-lfs/git-lfs/releases

### Web-based (check manually or note in PR):
- [ ] **Node.js LTS** - Current: `ENV NODE_LTS_VERSION` - Check: https://nodejs.org/en
- [ ] **Miniconda** - Current: `ENV MINICONDA_VERSION` and `ENV MINICONDA_SHA256` - Check: https://www.anaconda.com/docs/getting-started/miniconda/release-notes and https://repo.anaconda.com/miniconda/ (py312_Linux-x86_64)
- [ ] **Kubernetes CLI** - Current: `ENV KUBECTL_VERSION` - Check: https://user-guide.cloud-platform.service.justice.gov.uk/documentation/getting-started/kubectl-config.html
- [ ] **NVIDIA CUDA** (major/minor version) - Current: `ENV CUDA_VERSION` - Check: https://gitlab.com/nvidia/container-images/cuda/-/tree/master/dist

### Managed by other tools:
- **Ubuntu base image** - Managed by Dependabot
- **Base APT packages** - Managed by Renovate

## Instructions for Execution

### Using README.md Commands

The README.md file contains specific Docker commands for checking each package version. For example:

**For R:**
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

Similar commands exist in README.md for all other APT-based packages.

### Expected Output

1. **Compare** the latest versions found with current `ENV` variables in Dockerfile
2. **Update** only the versions that have changed
3. **Create a PR** with:
   - Clear commit message indicating which versions were updated
   - PR description listing old → new versions for each component
   - Reference this issue in the PR

### Special Considerations

- **NVIDIA CUDA**: Check both patch version updates AND major/minor version changes
- **Miniconda**: Update both version number AND SHA256 hash
- **Kubernetes CLI**: Must align with Cloud Platform documentation
- **Base APT packages**: Skip (managed by Renovate)
- **Ubuntu image**: Skip (managed by Dependabot)

## Manual Process (for reference)

If running manually, developers can:

1. Review the "Managing Software Versions" section in README.md
2. Run the documented commands for each component
3. Compare output with current Dockerfile ENV variables
4. Update Dockerfile with new versions
5. Test the build: `make build && make test`
6. Create PR with the changes

---

**Note**: This issue is tagged with `github-copilot-agent` to enable automated processing by GitHub Copilot's coding agent.
