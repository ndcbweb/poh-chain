# Agave stopped publishing validator binaries in 3.x, so they are built from the tagged source.
FROM ubuntu:24.04 AS build

ARG AGAVE_VERSION=v4.3.0
ARG RUST_VERSION=1.97.1

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl git build-essential pkg-config \
     libssl-dev libudev-dev zlib1g-dev llvm clang libclang-dev cmake make protobuf-compiler libprotobuf-dev \
  && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal -c rustfmt --default-toolchain "${RUST_VERSION}"
ENV PATH=/root/.cargo/bin:$PATH

RUN git clone --depth 1 --branch "${AGAVE_VERSION}" https://github.com/anza-xyz/agave /src \
  && cd /src \
  && cargo build --release --workspace \
       --bin agave-validator --bin solana-genesis --bin solana-keygen --bin solana \
  && mkdir -p /out \
  && cp target/release/agave-validator target/release/solana-genesis target/release/solana-keygen target/release/solana /out/ \
  && rm -rf /src /root/.cargo/registry /root/.cargo/git

FROM ubuntu:24.04

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl bzip2 jq libssl3t64 libudev1 zlib1g \
  && rm -rf /var/lib/apt/lists/*

COPY --from=build /out/ /usr/local/bin/
RUN agave-validator --version && solana-genesis --version

COPY programs.sh /opt/poh/programs.sh
RUN bash /opt/poh/programs.sh /opt/poh/programs

COPY bin/ /usr/local/bin/
RUN chmod 0755 /usr/local/bin/poh-*

ENV POH_DATA=/data
WORKDIR /data
