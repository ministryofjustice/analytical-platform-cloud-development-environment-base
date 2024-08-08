# Create workspace directory if it doesn't exist

echo "30-configure-aws-sso.sh"

if [[ ! -d "/home/${CONTAINER_USER}/.aws-sso" ]]; then
  echo "Creating AWS SSO directory"
  install --directory --owner "${CONTAINER_USER}" --group "${CONTAINER_GROUP}" --mode 0755 "/home/${CONTAINER_USER}/.aws-sso"

  install --owner="${CONTAINER_USER}" --group="${CONTAINER_GROUP}" --mode=0644 "${ANALYTICAL_PLATFORM_DIRECTORY}/aws-sso/config.yaml" "/home/${CONTAINER_USER}/.aws-sso/config.yaml"
fi
