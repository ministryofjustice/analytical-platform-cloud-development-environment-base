---
description: 'Describe what this custom agent does and when to use it.'
tools: ['runCommands', 'Copilot Container Tools/act_container', 'Copilot Container Tools/run_container', 'edit/editFiles', 'fetch', 'githubRepo']
---
The purpose of this agent is to the commands outlined in the README.md file to check for the latest versions of various software packages.

When the agent is run, it will replace the versions in the Dockerfile and test/container-structure-test.yml files with the latest versions obtained from running the commands.

Once the agent has updated the versions in the files, it will run `make test` to build and test the changes.

It will then commit the changes to a new branch in the repository and create a pull request with the changes.
