FROM golang:1.12.9-alpine3.10 as builder

# Force Go to use the cgo based DNS resolver. This is required to ensure DNS
# queries required to connect to linked containers succeed.
ENV GODEBUG netdns=cgo

# Install dependencies and build the binaries.
RUN apk add --no-cache --update alpine-sdk \
    git \
    make \
    gcc \
&&  git clone https://github.com/lightningnetwork/lnd --branch=v0.7.1-beta /go/src/github.com/lightningnetwork/lnd \
&&  cd /go/src/github.com/lightningnetwork/lnd \
&&  make \
&&  make install tags="signrpc walletrpc chainrpc invoicesrpc routerrpc"

# Start a new, final image.
FROM alpine:3.10 as final

# Add bash and ca-certs, for quality of life and SSL-related reasons.
RUN apk --no-cache add \
    bash \
    ca-certificates

# Add user and group for bitcoin process.
RUN addgroup -S lnd \
  && adduser -S lnd -G lnd \
  && mkdir /home/lnd/.lnd \
  && chown lnd:lnd /home/lnd/.lnd

# Change user.
USER lnd

# Define a root volume for data persistence.
VOLUME ["/home/lnd/.lnd"]

# Copy the binaries from the builder image.
COPY --from=builder /go/bin/lncli /bin/
COPY --from=builder /go/bin/lnd /bin/

# Expose lnd ports (rest, p2p, rpc).
EXPOSE 8080 9735 10009

# Specify the start command and entrypoint as the lnd daemon.
ENTRYPOINT ["lnd"]
