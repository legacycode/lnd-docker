ARG LND_VERSION=v0.11.1-beta

FROM debian:buster-slim AS builder

ARG LND_VERSION

# Install dependencies and build the binaries.
RUN apt-get update --yes \
  && apt-get install --no-install-recommends --yes \
    ca-certificates=20190110 \
    dirmngr=2.2.12-1+deb10u1 \
    gpg=2.2.12-1+deb10u1 \
    gpg-agent=2.2.12-1+deb10u1 \
    wget=1.20.1-1.1 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /lnd

RUN set -eux; \
  arch="$(dpkg --print-architecture)"; \
  case "$arch" in \
    i386) \
      url=https://github.com/lightningnetwork/lnd/releases/download/$LND_VERSION/lnd-linux-386-$LND_VERSION.tar.gz ;; \
    amd64) \
      url=https://github.com/lightningnetwork/lnd/releases/download/$LND_VERSION/lnd-linux-amd64-$LND_VERSION.tar.gz ;; \
    armhf) \
      url=https://github.com/lightningnetwork/lnd/releases/download/$LND_VERSION/lnd-linux-armv7-$LND_VERSION.tar.gz ;; \
    arm64) \
      url=https://github.com/lightningnetwork/lnd/releases/download/$LND_VERSION/lnd-linux-arm64-$LND_VERSION.tar.gz ;; \
    *) \
      echo >&2 "error: unsupported architecture ($arch)"; exit 1 ;;\
  esac; \
  \
  wget --quiet $url \
  && wget --quiet https://keybase.io/bitconner/pgp_keys.asc \
  && wget --quiet https://github.com/lightningnetwork/lnd/releases/download/$LND_VERSION/manifest-$LND_VERSION.txt \
  && wget --quiet https://github.com/lightningnetwork/lnd/releases/download/$LND_VERSION/manifest-$LND_VERSION.txt.sig \
  && gpg --import pgp_keys.asc \
  && gpg --verify manifest-$LND_VERSION.txt.sig \
  && grep "${url##*/}" manifest-$LND_VERSION.txt | sha256sum -c - \
  && tar -xzf ./*.tar.gz -C /lnd --strip-components=1


# Start a new, final image.
FROM debian:buster-slim AS final

ARG BUILD_DATE
ARG VCS_REF
ARG LND_VERSION

LABEL org.label-schema.schema-version="1.0" \
  org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.name="legacycode/lnd" \
  org.label-schema.description="A Docker image based on Debian Linux ready to run a Lightning node!" \
  org.label-schema.usage="https://hub.docker.com/r/legacycode/lnd" \
  org.label-schema.url="https://hub.docker.com/r/legacycode/lnd" \
  org.label-schema.vcs-url="https://github.com/legacycode/lnd-docker" \
  org.label-schema.vcs-ref=$VCS_REF \
  org.label-schema.version=$LND_VERSION \
  maintainer="info@legacycode.org"

# Add user and group for bitcoin process.
RUN useradd -r lnd \
  && mkdir -p /home/lnd/.lnd \
  && chmod 700 /home/lnd/.lnd \
  && chown -R lnd /home/lnd/.lnd

# Change user.
USER lnd

# Define a root volume for data persistence.
VOLUME ["/home/lnd/.lnd"]

# Copy the binaries from the builder image.
COPY --from=builder /lnd/lncli /bin/
COPY --from=builder /lnd/lnd /bin/

# Expose lnd ports (rest, p2p, rpc).
EXPOSE 8080 9735 10009

# Specify the start command and entrypoint as the lnd daemon.
ENTRYPOINT ["lnd"]
