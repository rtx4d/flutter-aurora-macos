#!/bin/bash
set -e

PSDK_VERSION_BASE="${1:-AuroraOS-5.2.1.70-base}"
INPUT_DIR="${2:-/parentroot/tmp/psdk_input}"

echo ">>> debug: ls of INPUT_DIR via shell expansion (no glob):"
echo ${INPUT_DIR}/Aurora_OS-5.2.1.70-Aurora_SDK_Target-armv7hl.tar.7z
ls -la ${INPUT_DIR}/Aurora_OS-5.2.1.70-Aurora_SDK_Target-armv7hl.tar.7z 2>&1 || true

sed \
    's|enter "$type:$object" dbus-uuidgen --ensure|enter "$type:$object" true|; s|enter "$type:$object" cp /var/lib/dbus/machine-id /etc/machine-id|enter "$type:$object" true|' \
    /usr/bin/sdk-manage > /tmp/sdk-manage-patched
chmod +x /tmp/sdk-manage-patched

for arch in armv7hl aarch64; do
    target="${PSDK_VERSION_BASE}-${arch}"
    tarball="${INPUT_DIR}/Aurora_OS-5.2.1.70-Aurora_SDK_Target-${arch}.tar.7z"
    if [ ! -f "${tarball}" ]; then
        echo ">>> ERROR: ${tarball} not found" >&2
        exit 1
    fi
    echo ">>> Installing ${target} from ${tarball}"
    /tmp/sdk-manage-patched target install "${target}" "file://${tarball}" --tooling "${PSDK_VERSION_BASE}"
done

rm -f /tmp/sdk-manage-patched

echo ">>> Final target list:"
sb2-config -l
