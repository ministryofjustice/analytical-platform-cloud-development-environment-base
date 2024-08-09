FROM ghcr.io/ministryofjustice/analytical-platform-cloud-development-environment-base:local

ENV JUPYTERLAB_VERSION="4.2.4" \
    JUPYTERLAB_GIT_VERSION="0.50.1"

USER root

# JupyterLab
RUN <<EOF
pip install --no-cache-dir \
  "jupyterlab==${JUPYTERLAB_VERSION}" \
  "jupyterlab-git==${JUPYTERLAB_GIT_VERSION}"
EOF

USER ${CONTAINER_USER}
EXPOSE 8080
COPY --chown=nobody:nobody --chmod=0755 src/usr/local/bin/entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
