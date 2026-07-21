FROM lscr.io/linuxserver/code-server:4.128.0-ls351@sha256:dfc5e74083f43f3cb217fedfead149f32b319ee663744351c001bdc5e4245441
LABEL org.opencontainers.image.source="https://github.com/tomas-fuerl/codeserver"

ARG TARGETARCH
ARG NODE_VERSION=24.18.0
ARG PNPM_VERSION=10.13.1
ARG POWERSHELL_VERSION=7.6.3
ARG CODEX_VERSION="0.144.5"

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

# Installiert die globalen Node.js-Werkzeuge in exakt festgelegten Versionen.
RUN npm install --global \
        "pnpm@${PNPM_VERSION}" \
        "@openai/codex@${CODEX_VERSION}" \
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
    && rsync --version \
    && shellcheck --version \
    && ssh -V \
    && tree --version \
    && unzip -v \
    && zip -v >/dev/null \
    && echo "Alle Build-Werkzeuge wurden erfolgreich geprüft."
