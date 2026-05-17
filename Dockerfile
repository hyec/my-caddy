ARG CADDY_DOCKER_VERSION

FROM caddy:${CADDY_DOCKER_VERSION}-builder AS builder

ARG CADDY_VERSION
ARG XCADDY_ARGS=""

RUN set -eux; \
    xcaddy build "${CADDY_VERSION}" --output /usr/bin/caddy ${XCADDY_ARGS}

FROM caddy:${CADDY_DOCKER_VERSION}

ARG CADDY_VERSION
ARG IMAGE_VERSION
ARG PLUGINS_JSON="[]"
ARG PLUGINS_SHA256
ARG SOURCE_URL

LABEL org.opencontainers.image.source="${SOURCE_URL}" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      io.github.my-caddy.caddy.version="${CADDY_VERSION}" \
      io.github.my-caddy.plugins="${PLUGINS_JSON}" \
      io.github.my-caddy.plugins.sha256="${PLUGINS_SHA256}"

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
