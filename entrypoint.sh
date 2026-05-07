#!/bin/bash
set -e

sudo setfacl -m "u:${DEV_USER}:r" \
    /etc/sudoers.d/sdk-chroot \
    /etc/sudoers.d/mer-sdk-chroot 2>/dev/null || true

exec "$@"
