FROM ubuntu:24.04

ARG AGAVE_VERSION=v4.3.0

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl bzip2 jq \
  && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL --retry 5 \
    "https://github.com/anza-xyz/agave/releases/download/${AGAVE_VERSION}/solana-release-x86_64-unknown-linux-gnu.tar.bz2" \
    | tar -xj -C /tmp \
  && for bin in agave-validator agave-ledger-tool solana solana-genesis solana-gossip solana-keygen; do \
       install -m 0755 "/tmp/solana-release/bin/$bin" /usr/local/bin/; \
     done \
  && rm -rf /tmp/solana-release \
  && agave-validator --version

COPY programs.sh /opt/poh/programs.sh
RUN bash /opt/poh/programs.sh /opt/poh/programs

COPY bin/ /usr/local/bin/
RUN chmod 0755 /usr/local/bin/poh-*

ENV POH_DATA=/data
WORKDIR /data
