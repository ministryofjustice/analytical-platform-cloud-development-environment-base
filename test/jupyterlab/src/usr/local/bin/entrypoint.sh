#!/usr/bin/env bash

bash /opt/analytical-platform/init/10-restore-bash.sh
bash /opt/analytical-platform/init/20-create-workspace.sh
bash /opt/analytical-platform/init/30-configure-aws-sso.sh

# Start JupyterLab
jupyter lab \
  --JupyterApp.answer_yes="True" \
  --ServerApp.open_browser="False" \
  --ServerApp.ip="0.0.0.0" \
  --ServerApp.port="8080" \
  --IdentityProvider.token="" \
  --LabApp.extension_manager="readonly" \
  --ServerApp.terminado_settings="shell_command=['/bin/bash']" \
  --notebook-dir="/home/analyticalplatform/workspace"
