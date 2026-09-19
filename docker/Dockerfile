FROM debian:12-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251 AS builder

ARG KAIJU_VERSION=1.10.3
ARG KAIJU_COMMIT=a36cd21d1c04d17a4f7e3744c17e8e8508e69e3b
ARG KAIJU_SHA256=712dc0b73944349ddf0e49b61e780864244e901ca89cd5c80180a97130a724d5
ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    for attempt in 1 2 3 4 5; do \
      if apt-get -o Acquire::Retries=3 update \
       && apt-get -o Acquire::Retries=3 install -y --no-install-recommends \
            ca-certificates \
            curl \
            g++ \
            gcc \
            make \
            zlib1g-dev; then \
        break; \
      fi; \
      if [ "${attempt}" = "5" ]; then exit 1; fi; \
      apt-get clean; \
      rm -rf /var/lib/apt/lists/*; \
      sleep 5; \
    done; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/kaiju-build

RUN set -eux; \
    curl --retry 5 --retry-delay 2 --retry-all-errors -fsSL \
      "https://github.com/bioinformatics-centre/kaiju/archive/refs/tags/v${KAIJU_VERSION}.tar.gz" \
      -o kaiju.tar.gz; \
    echo "${KAIJU_SHA256}  kaiju.tar.gz" | sha256sum -c -; \
    mkdir src; \
    tar -xzf kaiju.tar.gz -C src --strip-components=1; \
    make -C src/src -j "$(nproc)" \
      CFLAGS="-O3 -DNDEBUG -fsigned-char" \
      CXXFLAGS="-O3 -pthread -std=c++11 -DNDEBUG -fsigned-char"; \
    for name in \
      kaiju kaiju-multi kaijup kaijux kaiju2krona kaiju2table \
      kaiju-addTaxonNames kaiju-mergeOutputs kaiju-convertNR \
      kaiju-convertRefSeq kaiju-mkbwt kaiju-mkfmi; do \
      strip "src/bin/${name}"; \
    done; \
    install -d \
      /opt/kaiju/bin \
      /opt/kaiju/share/doc/kaiju \
      /opt/kaiju/share/licenses/kaiju \
      /opt/kaiju/share/testdata; \
    for name in \
      kaiju kaiju-multi kaijup kaijux kaiju2krona kaiju2table \
      kaiju-addTaxonNames kaiju-mergeOutputs kaiju-convertNR \
      kaiju-convertRefSeq kaiju-mkbwt kaiju-mkfmi; do \
      install -m 0755 "src/bin/${name}" "/opt/kaiju/bin/${name}"; \
    done; \
    install -m 0755 src/bin/kaiju-makedb /opt/kaiju/bin/kaiju-makedb; \
    install -m 0755 src/bin/kaiju-gbk2faa.pl /opt/kaiju/bin/kaiju-gbk2faa.pl; \
    install -m 0644 src/bin/kaiju-taxonlistEuk.tsv /opt/kaiju/bin/kaiju-taxonlistEuk.tsv; \
    install -m 0644 src/bin/kaiju-excluded-accessions.txt /opt/kaiju/bin/kaiju-excluded-accessions.txt; \
    install -m 0644 src/README.md /opt/kaiju/share/doc/kaiju/README.md; \
    install -m 0644 src/Quickstart.md /opt/kaiju/share/doc/kaiju/Quickstart.md; \
    install -m 0644 src/LICENSE /opt/kaiju/share/licenses/kaiju/LICENSE; \
    install -m 0644 src/src/include/zstr/LICENSE /opt/kaiju/share/licenses/kaiju/ZSTR-MIT.txt; \
    sed -n '1,20p' src/src/include/ncbi-blast+/connect/ncbi_core.h \
      > /opt/kaiju/share/licenses/kaiju/NCBI-PUBLIC-DOMAIN-NOTICE.txt; \
    { \
      echo "Kaiju ${KAIJU_VERSION}"; \
      echo "source=https://github.com/bioinformatics-centre/kaiju/archive/refs/tags/v${KAIJU_VERSION}.tar.gz"; \
      echo "source_sha256=${KAIJU_SHA256}"; \
      echo "upstream_tag=v${KAIJU_VERSION}"; \
      echo "upstream_commit=${KAIJU_COMMIT}"; \
      echo "runtime_banner_version=1.10.3"; \
      echo "release_identity=v1.10.3 fixes RefSeq URLs and adds viral proteins to refseq_nr"; \
      echo "build=official C/C++11 source makefile with explicit signed-char semantics"; \
      echo "upstream_license=GPL-3.0-or-later"; \
      echo "bundled_zstr_license=MIT"; \
      echo "bundled_ncbi_blast_core_notice=public-domain notice retained"; \
    } > /opt/kaiju/share/doc/kaiju/source.txt

FROM debian:12-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251

LABEL org.opencontainers.image.title="kaiju" \
      org.opencontainers.image.description="TAFFISH wrapper for Kaiju protein-level taxonomic classification" \
      org.opencontainers.image.source="https://github.com/bioinformatics-centre/kaiju" \
      org.opencontainers.image.licenses="Apache-2.0"

ARG KAIJU_VERSION=1.10.3
ENV DEBIAN_FRONTEND=noninteractive \
    PATH=/opt/kaiju/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN set -eux; \
    for attempt in 1 2 3 4 5; do \
      if apt-get -o Acquire::Retries=3 update \
       && apt-get -o Acquire::Retries=3 install -y --no-install-recommends \
            bzip2 \
            ca-certificates \
            coreutils \
            curl \
            findutils \
            mawk \
            gzip \
            grep \
            libc-bin \
            libio-compress-perl \
            libstdc++6 \
            perl \
            python3 \
            sed \
            tar \
            wget \
            xz-utils \
            zlib1g; then \
        break; \
      fi; \
      if [ "${attempt}" = "5" ]; then exit 1; fi; \
      apt-get clean; \
      rm -rf /var/lib/apt/lists/*; \
      sleep 5; \
    done; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY --from=builder /opt/kaiju /opt/kaiju
COPY docker/kaiju-smoke.sh /opt/kaiju/share/testdata/kaiju-smoke.sh
COPY docker/kaiju-db.py /opt/kaiju/bin/kaiju-db
COPY docker/kaiju-resource-smoke.py /opt/kaiju/share/testdata/kaiju-resource-smoke.py

RUN set -eux; \
    chmod 0755 /opt/kaiju/share/testdata/kaiju-smoke.sh; \
    chmod 0755 /opt/kaiju/bin/kaiju-db; \
    kaiju-db --version; \
    grep -F "source_sha256=712dc0b73944349ddf0e49b61e780864244e901ca89cd5c80180a97130a724d5" \
      /opt/kaiju/share/doc/kaiju/source.txt >/dev/null; \
    kaiju -h 2>&1 | grep -Fx "Kaiju 1.10.3" >/dev/null; \
    kaijup -h 2>&1 | grep -F "Disable SEG low complexity filter" >/dev/null; \
    kaijux -h 2>&1 | grep -F "Disable SEG low complexity filter" >/dev/null; \
    for name in \
      kaiju kaiju-multi kaijup kaijux kaiju2krona kaiju2table \
      kaiju-addTaxonNames kaiju-mergeOutputs kaiju-convertNR \
      kaiju-convertRefSeq kaiju-mkbwt kaiju-mkfmi; do \
      ldd "$(command -v "${name}")" >> /tmp/kaiju-ldd.txt; \
    done; \
    if grep -F "not found" /tmp/kaiju-ldd.txt; then exit 1; fi; \
    /opt/kaiju/share/testdata/kaiju-smoke.sh \
      buildtime /tmp/taf-kaiju-build-check; \
    rm -rf /tmp/kaiju-ldd.txt

ENV TAFFISH_ENV=TAFFISH \
    TAFFISH_NAME=kaiju \
    TAFFISH_VERSION=${KAIJU_VERSION} \
    TAFFISH_RELEASE=1

WORKDIR /work
