#!/usr/bin/env bash

bash /opt/analytical-platform/init/10-restore-bash.sh
bash /opt/analytical-platform/init/20-create-workspace.sh
bash /opt/analytical-platform/init/30-configure-aws-sso.sh

# Start Visual Studio Code Server
/usr/bin/code serve-web \
  --without-connection-token \
  --accept-server-license-terms \
  --host 0.0.0.0 \
  --port 8080
