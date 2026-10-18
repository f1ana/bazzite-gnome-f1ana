#!/usr/bin/env bash
# Assert that an image's initramfs can be unlocked over SSH.
# Usage: check-unlock-initramfs.sh <image-ref> [<repo-root>]
# Prints one PASS:/FAIL: line per assertion; exits 0 only if all pass.
set -u

image=${1:?usage: $0 <image-ref> [<repo-root>]}
repo=${2:-.}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fails=0
check() { # check <description> <command...>
    local desc=$1
    shift
    if "$@"; then
        echo "PASS: $desc"
    else
        echo "FAIL: $desc"
        fails=$((fails + 1))
    fi
}

# One container run: collect everything needed, base64-encode file contents so
# bytes (and missing trailing newlines) survive the trip.
podman run --rm "$image" bash -c '
    img=$(ls /usr/lib/modules/*/initramfs.img | head -n1) || exit 1
    echo "@@LIST"
    lsinitrd "$img"
    for f in etc/ssh/ssh_host_ed25519_key.pub root/.ssh/authorized_keys etc/sysconfig/dracut-sshd; do
        echo "@@FILE $f"
        lsinitrd -f "$f" "$img" 2>/dev/null | base64 -w0
        echo
    done
    echo "@@KARGS"
    for f in /usr/lib/bootc/kargs.d/*; do
        [ -f "$f" ] && grep -q "rd.neednet=1" "$f" && grep -q "ip=dhcp" "$f" && echo "$f"
    done
    echo "@@SHADOW"
    grep "^root:" /etc/shadow | cut -c1-6
    echo "@@END"
' >"$tmp/raw" 2>"$tmp/err"
if ! grep -q '^@@END$' "$tmp/raw"; then
    echo "FAIL: could not inspect image $image"
    sed 's/^/  /' "$tmp/err" | tail -n 5
    exit 1
fi

# Split the stream into one file per section.
awk -v dir="$tmp" '
    /^@@LIST$/   { out = dir "/list";   next }
    /^@@FILE /   { n = $2; gsub("/", "_", n); out = dir "/file_" n; next }
    /^@@KARGS$/  { out = dir "/kargs";  next }
    /^@@SHADOW$/ { out = dir "/shadow"; next }
    /^@@END$/    { out = ""; next }
    out != ""    { print > out }
' "$tmp/raw"
touch "$tmp/list" "$tmp/kargs" "$tmp/shadow"
for f in "$tmp"/file_*; do base64 -d <"$f" >"$f.dec" 2>/dev/null; done

in_list() { awk -v p="$1" '$9 == p { found = 1 } END { exit !found }' "$tmp/list"; }
mode_of() { awk -v p="$1" '$9 == p { print $1; exit }' "$tmp/list"; }
is_link() { [ "$(mode_of "$1" | cut -c1)" = "l" ]; }
same() { # same <extracted-file> <repo-file>
    [ -s "$1" ] && [ -f "$2" ] && cmp -s "$1" "$2"
}

hostkey_ok() {
    [ "$(mode_of etc/ssh/ssh_host_ed25519_key)" = "-rw-------" ] &&
        same "$tmp/file_etc_ssh_ssh_host_ed25519_key.pub.dec" \
            "$repo/files/system/etc/ssh/dracut_ssh_host_ed25519_key.pub"
}
authkeys_ok() {
    [ "$(mode_of root/.ssh/authorized_keys)" = "-rw-------" ] &&
        same "$tmp/file_root_.ssh_authorized_keys.dec" \
            "$repo/files/system/etc/dracut-sshd/authorized_keys"
}
sshd_opts_ok() {
    [ "$(cat "$tmp/file_etc_sysconfig_dracut-sshd.dec")" = 'SSHD_OPTS="-p 2222"' ]
}
sshd_service_ok() {
    in_list usr/lib/systemd/system/sshd.service &&
        is_link etc/systemd/system/sysinit.target.wants/sshd.service
}
network_ok() {
    in_list usr/bin/NetworkManager && in_list usr/libexec/nm-initrd-generator
}
modules_ok() {
    local line m
    line=$(grep -m1 '^dracut modules:' -A200 "$tmp/list" | tr '\n' ' ')
    for m in fido2 pcsc pkcs11 tpm2-tss; do
        [[ " $line " == *" $m "* ]] || return 1
    done
}
kargs_ok() { [ -s "$tmp/kargs" ]; }
root_locked_star() { [ "$(cat "$tmp/shadow")" = "root:*" ]; }

check "usr/bin/sshd is in the initramfs" in_list usr/bin/sshd
check "dedicated host key (0600) and matching .pub are in the initramfs" hostkey_ok
check "root authorized_keys (0600) matches the repo" authkeys_ok
check "etc/sysconfig/dracut-sshd is SSHD_OPTS=\"-p 2222\"" sshd_opts_ok
check "sshd.service is present and enabled in sysinit.target.wants" sshd_service_ok
check "NetworkManager and nm-initrd-generator are in the initramfs" network_ok
check "Bazzite dracut modules (fido2 pcsc pkcs11 tpm2-tss) are still present" modules_ok
check "a kargs.d file sets rd.neednet=1 and ip=dhcp" kargs_ok
check "image /etc/shadow root field starts with 'root:*'" root_locked_star

[ "$fails" -eq 0 ]
