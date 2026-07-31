FROM lscr.io/linuxserver/code-server:4.131.0-ls354@sha256:621d47575a19645f4267f68a77167ca0b4562d042717dbe0dbba318c9753bad7
LABEL org.opencontainers.image.source="https://github.com/tomas-fuerl/codeserver"

ARG TARGETARCH
ARG NODE_VERSION=24.18.0
ARG GH_VERSION=2.96.0
ARG PNPM_VERSION=11.4.0
ARG PNPM_SHA512=f0febc7e37552ab485494a914241b338e0b3580b93d54ce31f00933015880863129038a1b4ae4e414a0ee63ac35bf21197e990172c4a68256450b5636310968f
ARG POWERSHELL_VERSION=7.6.3
ARG CODEX_VERSION="0.144.5"
ARG PG_CLIENT_VERSION=18.4-1.pgdg24.04+1
ARG DOCKER_CLI_VERSION=5:29.7.0-1~ubuntu.24.04~noble
ARG DOCKER_COMPOSE_VERSION=5.3.1-1~ubuntu.24.04~noble
ARG DOCKER_BUILDX_VERSION=0.36.0-1~ubuntu.24.04~noble
ARG TRIVY_VERSION=0.72.0
ARG TRIVY_CHECKSUMS_SHA256=ebe9d19a774b950e240b1017a038e9b5a002ea068e02023369ff6d241c10c580
ARG TRIVY_AMD64_SHA256=bbb64b9695866ce4a7a8f5c9592002c5961cab378577fa3f8a040df362b9b2ea
ARG TRIVY_ARM64_SHA256=2ca2c023109c2db6b2b77366b6717291452d4531167377d95c79547f0c8e3467

ENV GH_TELEMETRY=false

USER root

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Grundlegende Laufzeit-, Build-, Diagnose- und Entwicklerwerkzeuge.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        argon2 \
        bash-completion \
        bubblewrap \
        build-essential \
        ca-certificates \
        curl \
        dnsutils \
        fd-find \
        git \
        gpg \
        iputils-ping \
        jq \
        less \
        libicu74 \
        libssl3 \
        libunwind8 \
        lsof \
        netcat-openbsd \
        openssh-client \
        procps \
        python3 \
        ripgrep \
        rsync \
        shellcheck \
        tar \
        tree \
        unzip \
        xz-utils \
        zip \
        zlib1g \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && . /etc/os-release \
    && [[ "${ID:-}" == "ubuntu" && "${VERSION_CODENAME:-}" == "noble" ]] \
    && APT_ARCH="$(dpkg --print-architecture)" \
    && case "${APT_ARCH}" in amd64|arm64) ;; *) echo "Nicht unterstützte Architektur: ${APT_ARCH}" >&2; exit 1 ;; esac \
    && install -d -m 0755 /etc/apt/keyrings \
    && curl --fail --show-error --location --retry 3 \
        --output /etc/apt/keyrings/apt.postgresql.org.asc \
        https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    && curl --fail --show-error --location --retry 3 \
        --output /etc/apt/keyrings/docker.asc \
        https://download.docker.com/linux/ubuntu/gpg \
    && PGDG_FINGERPRINT="B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8" \
    && DOCKER_FINGERPRINT="9DC858229FC7DD38854AE2D88D81803C0EBFCD88" \
    && gpg --show-keys --with-colons /etc/apt/keyrings/apt.postgresql.org.asc \
        | awk -F: '$1 == "fpr" { print toupper($10) }' \
        | grep -Fxq "${PGDG_FINGERPRINT}" \
    && gpg --show-keys --with-colons /etc/apt/keyrings/docker.asc \
        | awk -F: '$1 == "fpr" { print toupper($10) }' \
        | grep -Fxq "${DOCKER_FINGERPRINT}" \
    && printf '%s\n' \
        "Types: deb" \
        "URIs: https://apt.postgresql.org/pub/repos/apt" \
        "Suites: noble-pgdg" \
        "Components: main" \
        "Architectures: ${APT_ARCH}" \
        "Signed-By: /etc/apt/keyrings/apt.postgresql.org.asc" \
        >/etc/apt/sources.list.d/pgdg.sources \
    && printf '%s\n' \
        "Types: deb" \
        "URIs: https://download.docker.com/linux/ubuntu" \
        "Suites: noble" \
        "Components: stable" \
        "Architectures: ${APT_ARCH}" \
        "Signed-By: /etc/apt/keyrings/docker.asc" \
        >/etc/apt/sources.list.d/docker.sources \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        "postgresql-client-18=${PG_CLIENT_VERSION}" \
        "docker-ce-cli=${DOCKER_CLI_VERSION}" \
        "docker-compose-plugin=${DOCKER_COMPOSE_VERSION}" \
        "docker-buildx-plugin=${DOCKER_BUILDX_VERSION}" \
    && apt-get purge -y --auto-remove gpg \
    && rm -f /etc/apt/sources.list.d/pgdg.sources \
        /etc/apt/sources.list.d/docker.sources \
        /etc/apt/keyrings/apt.postgresql.org.asc \
        /etc/apt/keyrings/docker.asc \
    && rm -rf /var/lib/apt/lists/*

# Installiert eine exakt festgelegte Node.js-Version und prüft das Archiv
# gegen die offizielle Prüfsummenliste derselben Version.
RUN BUILD_ARCH="${TARGETARCH:-$(dpkg --print-architecture)}" \
    && case "${BUILD_ARCH}" in \
        amd64) NODE_ARCH="x64" ;; \
        arm64) NODE_ARCH="arm64" ;; \
        *) echo "Nicht unterstützte Architektur: ${BUILD_ARCH}" >&2; exit 1 ;; \
    esac \
    && NODE_ARCHIVE="node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" \
    && curl --fail --show-error --location --retry 3 \
        --output "/tmp/${NODE_ARCHIVE}" \
        "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_ARCHIVE}" \
    && curl --fail --show-error --location --retry 3 \
        --output /tmp/SHASUMS256.txt \
        "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" \
    && grep " ${NODE_ARCHIVE}$" /tmp/SHASUMS256.txt \
        | sed 's#  #  /tmp/#' \
        | sha256sum --check --strict - \
    && tar --extract --xz --file "/tmp/${NODE_ARCHIVE}" \
        --directory /usr/local --strip-components=1 \
    && rm -f "/tmp/${NODE_ARCHIVE}" /tmp/SHASUMS256.txt

# Installiert die GitHub CLI aus dem offiziellen Releasearchiv und prüft
# Prüfsummenliste sowie Archiv vor der Installation strikt.
RUN BUILD_ARCH="${TARGETARCH:-$(dpkg --print-architecture)}" \
    && case "${BUILD_ARCH}" in \
        amd64) GH_ARCH="amd64" ;; \
        arm64) GH_ARCH="arm64" ;; \
        *) echo "Nicht unterstützte Architektur: ${BUILD_ARCH}" >&2; exit 1 ;; \
    esac \
    && GH_ARCHIVE="gh_${GH_VERSION}_linux_${GH_ARCH}.tar.gz" \
    && GH_CHECKSUMS="gh_${GH_VERSION}_checksums.txt" \
    && GH_CHECKSUMS_SHA256="fc046371efa250e2875208341a786a35a01717d5eebec6903e199a9b8a3f3565" \
    && curl --fail --show-error --location --retry 3 \
        --output "/tmp/${GH_ARCHIVE}" \
        "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${GH_ARCHIVE}" \
    && curl --fail --show-error --location --retry 3 \
        --output "/tmp/${GH_CHECKSUMS}" \
        "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${GH_CHECKSUMS}" \
    && echo "${GH_CHECKSUMS_SHA256}  /tmp/${GH_CHECKSUMS}" \
        | sha256sum --check --strict - \
    && awk -v archive="${GH_ARCHIVE}" \
        '$2 == archive && NF == 2 && length($1) == 64 && $1 !~ /[^0-9a-f]/ { count += 1; checksum = $1 } END { if (count != 1) exit 1; print checksum "  /tmp/" archive }' \
        "/tmp/${GH_CHECKSUMS}" \
        | sha256sum --check --strict - \
    && mkdir -p "/opt/github-cli/${GH_VERSION}" \
    && tar --extract --gzip --file "/tmp/${GH_ARCHIVE}" \
        --directory "/opt/github-cli/${GH_VERSION}" --strip-components=1 \
    && chmod +x "/opt/github-cli/${GH_VERSION}/bin/gh" \
    && ln -sf \
        "/opt/github-cli/${GH_VERSION}/bin/gh" \
        /usr/local/bin/gh \
    && rm -f "/tmp/${GH_ARCHIVE}" "/tmp/${GH_CHECKSUMS}" \
    && command -v gh \
    && gh --version

# Installiert die globalen Node.js-Werkzeuge in exakt festgelegten Versionen.
RUN npm install --global \
        "@openai/codex@${CODEX_VERSION}" \
    && npm pack --ignore-scripts --pack-destination /tmp \
        "pnpm@${PNPM_VERSION}" \
    && echo "${PNPM_SHA512}  /tmp/pnpm-${PNPM_VERSION}.tgz" \
        | sha512sum --check --strict - \
    && npm install --global --ignore-scripts \
        "/tmp/pnpm-${PNPM_VERSION}.tgz" \
    && rm -f "/tmp/pnpm-${PNPM_VERSION}.tgz" \
    && command -v pnpm \
    && command -v codex \
    && pnpm --version \
    && codex --version \
    && npm cache clean --force

# PowerShell wird als festgelegtes Release-Archiv installiert.
# Die SHA-256-Prüfsummen stammen aus dem offiziellen PowerShell-Release.
RUN BUILD_ARCH="${TARGETARCH:-$(dpkg --print-architecture)}" \
    && case "${BUILD_ARCH}" in \
        amd64) \
            PWSH_ARCH="x64"; \
            PWSH_SHA256="856D0765D2332377F9D7A4AEA76EFDFDE4DE51446E7738DDE2DFDA41DBA9E2A7" \
            ;; \
        arm64) \
            PWSH_ARCH="arm64"; \
            PWSH_SHA256="7A14A385ECA7DC5BEDC1C8AA3D8B765F449ADA30AABE5785A9FD331266EB062D" \
            ;; \
        *) echo "Nicht unterstützte Architektur: ${BUILD_ARCH}" >&2; exit 1 ;; \
    esac \
    && PWSH_ARCHIVE="powershell-${POWERSHELL_VERSION}-linux-${PWSH_ARCH}.tar.gz" \
    && curl --fail --show-error --location --retry 3 \
        --output "/tmp/${PWSH_ARCHIVE}" \
        "https://github.com/PowerShell/PowerShell/releases/download/v${POWERSHELL_VERSION}/${PWSH_ARCHIVE}" \
    && echo "${PWSH_SHA256}  /tmp/${PWSH_ARCHIVE}" \
        | sha256sum --check --strict - \
    && mkdir -p "/opt/microsoft/powershell/${POWERSHELL_VERSION}" \
    && tar --extract --gzip --file "/tmp/${PWSH_ARCHIVE}" \
        --directory "/opt/microsoft/powershell/${POWERSHELL_VERSION}" \
    && chmod +x "/opt/microsoft/powershell/${POWERSHELL_VERSION}/pwsh" \
    && ln -sf \
        "/opt/microsoft/powershell/${POWERSHELL_VERSION}/pwsh" \
        /usr/local/bin/pwsh \
    && rm -f "/tmp/${PWSH_ARCHIVE}"

# Trivy wird ausschließlich aus dem offiziellen Aqua-Security-Releasearchiv
# installiert. Die offizielle Prüfsummenliste wird selbst checksum-geprüft.
RUN BUILD_ARCH="${TARGETARCH:-$(dpkg --print-architecture)}" \
    && case "${BUILD_ARCH}" in \
        amd64) \
            TRIVY_ARCH="64bit"; \
            TRIVY_SHA256="${TRIVY_AMD64_SHA256}" \
            ;; \
        arm64) \
            TRIVY_ARCH="ARM64"; \
            TRIVY_SHA256="${TRIVY_ARM64_SHA256}" \
            ;; \
        *) echo "Nicht unterstützte Architektur: ${BUILD_ARCH}" >&2; exit 1 ;; \
    esac \
    && TRIVY_ARCHIVE="trivy_${TRIVY_VERSION}_Linux-${TRIVY_ARCH}.tar.gz" \
    && TRIVY_CHECKSUMS="trivy_${TRIVY_VERSION}_checksums.txt" \
    && curl --fail --show-error --location --retry 3 \
        --output "/tmp/${TRIVY_ARCHIVE}" \
        "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/${TRIVY_ARCHIVE}" \
    && curl --fail --show-error --location --retry 3 \
        --output "/tmp/${TRIVY_CHECKSUMS}" \
        "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/${TRIVY_CHECKSUMS}" \
    && echo "${TRIVY_CHECKSUMS_SHA256}  /tmp/${TRIVY_CHECKSUMS}" \
        | sha256sum --check --strict - \
    && awk -v archive="${TRIVY_ARCHIVE}" -v expected="${TRIVY_SHA256}" \
        '$2 == archive && NF == 2 && $1 == expected { count += 1 } END { exit count == 1 ? 0 : 1 }' \
        "/tmp/${TRIVY_CHECKSUMS}" \
    && mkdir -p "/opt/aqua-security/trivy/${TRIVY_VERSION}" \
    && tar --extract --gzip --file "/tmp/${TRIVY_ARCHIVE}" \
        --directory "/opt/aqua-security/trivy/${TRIVY_VERSION}" trivy \
    && chmod +x "/opt/aqua-security/trivy/${TRIVY_VERSION}/trivy" \
    && ln -sf \
        "/opt/aqua-security/trivy/${TRIVY_VERSION}/trivy" \
        /usr/local/bin/trivy \
    && rm -f "/tmp/${TRIVY_ARCHIVE}" "/tmp/${TRIVY_CHECKSUMS}"

ENV TRIVY_CACHE_DIR=/config/.cache/trivy

# Der Build schlägt fehl, falls eines der zentralen Werkzeuge fehlt
# oder nicht ausgeführt werden kann.
RUN set -e \
    && command -v argon2 \
    && command -v bwrap \
    && command -v node \
    && command -v npm \
    && command -v pnpm \
    && command -v codex \
    && command -v pwsh \
    && command -v git \
    && command -v jq \
    && command -v python3 \
    && command -v gcc \
    && command -v g++ \
    && command -v make \
    && command -v rg \
    && command -v fd \
    && command -v gh \
    && command -v psql \
    && command -v pg_isready \
    && command -v pg_dump \
    && command -v pg_restore \
    && command -v docker \
    && command -v trivy \
    && test ! -S /var/run/docker.sock \
    && ! command -v dockerd \
    && ! command -v containerd \
    && for forbidden_package in docker-ce docker.io dockerd containerd containerd.io; do \
        if dpkg-query -W -f='${Status}' "${forbidden_package}" 2>/dev/null \
            | grep -Fq 'install ok installed'; then \
            echo "Verbotenes Docker-Daemonpaket installiert: ${forbidden_package}" >&2; \
            exit 1; \
        fi; \
    done \
    && command -v rsync \
    && command -v shellcheck \
    && command -v ssh \
    && command -v tree \
    && command -v unzip \
    && command -v zip \
    && printf 'build-test-password' \
    | argon2 'build-test-salt' \
        -id \
        -t 1 \
        -m 8 \
        -p 1 \
        -l 16 \
        -e \
        >/dev/null \
    && bwrap --version \
    && node --version \
    && npm --version \
    && pnpm --version \
    && codex --version \
    && pwsh --version \
    && git --version \
    && jq --version \
    && python3 --version \
    && gcc --version \
    && g++ --version \
    && make --version \
    && rg --version \
    && fd --version \
    && gh --version \
    && psql --version \
    && pg_isready --version \
    && pg_dump --version \
    && pg_restore --version \
    && docker --version \
    && docker compose version \
    && docker buildx version \
    && trivy --version \
    && rsync --version \
    && shellcheck --version \
    && ssh -V \
    && tree --version \
    && unzip -v \
    && zip -v >/dev/null \
    && echo "Alle Build-Werkzeuge wurden erfolgreich geprüft."

# Der Laufzeitcontainer bleibt beim unprivilegierten LinuxServer-Benutzer.
USER abc
