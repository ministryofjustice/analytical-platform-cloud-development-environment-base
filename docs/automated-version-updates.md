# Automated Version Updates with GitHub Copilot

This repository includes automation for checking and updating software versions using GitHub Copilot's coding agent.

## How It Works

### Scheduled Updates (Automatic)

A GitHub Actions workflow (`.github/workflows/version-update.yml`) runs weekly (every Monday at 9 AM UTC) and:

1. Creates a GitHub issue with detailed update instructions
2. Triggers the GitHub Copilot coding agent via a comment
3. The agent reads the instructions, checks all versions, and creates a PR with updates

### Manual Triggering

You can manually trigger an update check in two ways:

#### Option 1: Via GitHub Actions UI
1. Go to the "Actions" tab in GitHub
2. Select "Scheduled Version Updates" workflow
3. Click "Run workflow"
4. Optionally specify which components to check

#### Option 2: Via GitHub Copilot Chat
1. Open a conversation with GitHub Copilot
2. Reference the coding agent: `#github-pull-request_copilot-coding-agent`
3. Ask it to check and update versions, for example:

```
#github-pull-request_copilot-coding-agent

Please check all software versions from the README.md "Managing Software Versions" section,
compare them with the current Dockerfile ENV variables, and update any outdated versions.
Create a PR with the changes.
```

## What Gets Checked

The automation checks versions for:

- **APT packages**: Amazon Corretto, .NET SDK, R, NVIDIA CUDA, Microsoft ODBC Driver
- **GitHub releases**: AWS CLI, AWS SSO CLI, Ollama, Helm, Cloud Platform CLI, nbstripout, uv, git-lfs
- **Web sources**: Node.js LTS, Miniconda, Kubernetes CLI

Components managed by Dependabot and Renovate are skipped.

## Review Process

1. The Copilot agent creates a PR with version updates
2. Review the PR to ensure:
   - Only intended versions were updated
   - No breaking changes in new versions
   - SHA256 hashes are correct (for Miniconda, etc.)
3. CI/CD tests run automatically
4. Merge when ready

## Manual Updates (Alternative)

If you prefer to update manually:

1. See the "Managing Software Versions" section in the main README.md
2. Each component has specific commands documented
3. Run those commands to find latest versions
4. Update the Dockerfile ENV variables
5. Test: `make build && make test`
6. Create a PR

## Files Involved

- `.github/workflows/version-update.yml` - Scheduled workflow
- `.github/workflows/version-update-instructions.md` - Instructions for the agent
- `README.md` - Commands for checking each version
- `Dockerfile` - Where versions are defined

## Customization

Edit `.github/workflows/version-update-instructions.md` to:
- Add/remove components to check
- Modify the update frequency
- Adjust the instructions for the coding agent
