# syntax=docker/dockerfile:1-labs

ARG FLUTTER_VERSION=3.35.7
ARG PSDK_VERSION=5.2.1.70
ARG PSDK_URL=https://sdk-repo.omprussia.ru/sdk/installers/5.2.1/${PSDK_VERSION}-release/AuroraPSDK/

ARG DEV_USER=mer
ARG DEV_UID=1000
ARG DEV_GID=1000

# ============================================================
# Stage 1: base
# ============================================================
FROM --platform=linux/amd64 ubuntu:22.04 AS base

ARG DEV_USER
ARG DEV_UID
ARG DEV_GID

ENV DEBIAN_FRONTEND=noninteractive \
    TERM=xterm \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    DEV_USER=${DEV_USER} \
    HOME=/home/${DEV_USER} \
    USER=${DEV_USER}

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl wget gnupg locales \
        git git-lfs unzip bzip2 tar p7zip-full xz-utils \
        netcat-openbsd \
        sudo acl \
        python3 \
        openssh-client rsync \
        libglu1-mesa libsm6 libxext6 libxrender1 libglib2.0-0

RUN groupadd -g ${DEV_GID} ${DEV_USER} \
    && useradd -m -u ${DEV_UID} -g ${DEV_GID} -s /bin/bash ${DEV_USER} \
    && echo "${DEV_USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${DEV_USER} \
    && chmod 0440 /etc/sudoers.d/${DEV_USER}

# ============================================================
# Stage 2: flutter
# ============================================================
FROM base AS flutter

ARG DEV_USER
ARG FLUTTER_VERSION
ENV FLUTTER_HOME=/home/${DEV_USER}/.local/opt/flutter_aurora
ENV PATH=${FLUTTER_HOME}/bin:${PATH}

USER ${DEV_USER}
WORKDIR ${HOME}

RUN --mount=type=bind,source=cache/flutter_aurora_${FLUTTER_VERSION}.tar.gz,target=/tmp/flutter.tar.gz \
    mkdir -p "${FLUTTER_HOME}" \
    && tar xf /tmp/flutter.tar.gz -C "${FLUTTER_HOME}" --strip-components=1 \
    && git config --global --add safe.directory "${FLUTTER_HOME}"

# ============================================================
# Stage 3: psdk
# ============================================================
FROM flutter AS psdk

ARG DEV_USER
ARG PSDK_URL
ENV PSDK_DIR=/home/${DEV_USER}/AuroraPlatformSDK/sdks/aurora_psdk

USER ${DEV_USER}
WORKDIR /tmp

RUN --security=insecure \
    --mount=type=bind,source=cache/psdk_install-master.zip,target=/tmp/psdk_install-master.zip \
    --mount=type=bind,source=cache/psdk,target=/tmp/psdk_input,readonly \
    unzip -j /tmp/psdk_install-master.zip psdk_install-master/install_aurora_psdk.sh -d /tmp \
    && chmod +x /tmp/install_aurora_psdk.sh \
    && /tmp/install_aurora_psdk.sh \
        --input-dir /tmp/psdk_input \
        --install-dir ${HOME}/AuroraPlatformSDK \
        --toolchain-suffix base \
    && rm -f /tmp/install_aurora_psdk.sh

COPY --chmod=0755 install-cross-targets.sh /tmp/install-cross-targets.sh
RUN --security=insecure \
    sudo ${PSDK_DIR}/sdk-chroot /parentroot/tmp/install-cross-targets.sh \
        AuroraOS-5.2.1.70-base \
        /parentroot${HOME}/AuroraPlatformSDK/tarballs \
    && sudo rm -f /tmp/install-cross-targets.sh

# ============================================================
# Stage 4: final
# ============================================================
FROM psdk AS final

ARG DEV_USER

ENV PSDK_DIR=/home/${DEV_USER}/AuroraPlatformSDK/sdks/aurora_psdk \
    AURORA_SDK_DIR=/home/${DEV_USER}/AuroraOS \
    FLUTTER_HOME=/home/${DEV_USER}/.local/opt/flutter_aurora
ENV PATH=${FLUTTER_HOME}/bin:${PATH}

USER root
RUN printf '%s ALL=(ALL) NOPASSWD: %s/sdk-chroot\nDefaults!%s/sdk-chroot env_keep += "SSH_AGENT_PID SSH_AUTH_SOCK"\n' \
        "${DEV_USER}" "${PSDK_DIR}" "${PSDK_DIR}" > /etc/sudoers.d/sdk-chroot \
    && printf '%s ALL=(ALL) NOPASSWD: %s\nDefaults!%s env_keep += "SSH_AGENT_PID SSH_AUTH_SOCK"\n' \
        "${DEV_USER}" "${PSDK_DIR}" "${PSDK_DIR}" > /etc/sudoers.d/mer-sdk-chroot \
    && chown root:root /etc/sudoers.d/sdk-chroot /etc/sudoers.d/mer-sdk-chroot \
    && chmod 0440 /etc/sudoers.d/sdk-chroot /etc/sudoers.d/mer-sdk-chroot \
    && visudo -c

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh

USER ${DEV_USER}

RUN { \
      echo 'alias flutter-aurora="$HOME/.local/opt/flutter_aurora/bin/flutter"'; \
      echo 'alias dart-aurora="$HOME/.local/opt/flutter_aurora/bin/dart"'; \
      echo 'export PATH="$HOME/.local/opt/flutter_aurora/bin:$PATH"'; \
    } >> ${HOME}/.bashrc

RUN sudo setfacl -m "u:${DEV_USER}:r" /etc/sudoers.d/sdk-chroot /etc/sudoers.d/mer-sdk-chroot \
    && mkdir -p "${AURORA_SDK_DIR}/bin" "${HOME}/.scratchbox2" \
    && printf '#!/bin/sh\necho "sfdk stub 0.0.0 (no Aurora SDK installed)"\nexit 0\n' > "${AURORA_SDK_DIR}/bin/sfdk" \
    && chmod +x "${AURORA_SDK_DIR}/bin/sfdk" \
    && flutter config --aurora-psdk-dir="${PSDK_DIR}" \
    && flutter config --aurora-sdk-dir="${AURORA_SDK_DIR}" \
    && flutter config --enable-aurora-devices \
    && flutter config --no-analytics

RUN flutter doctor -v || true

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash", "-l"]
