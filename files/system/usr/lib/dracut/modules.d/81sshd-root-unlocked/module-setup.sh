#!/usr/bin/bash

# Give root a '*' (no password, not locked) entry in the initramfs /etc/shadow.
#
# Bazzite builds its initramfs with hostonly=no, so dracut's base module adds
# 'root::0:0' to passwd but no root line to shadow. The initramfs sshd has no
# PAM and reads shadow itself, and then treats root as locked and refuses
# public-key login ("User root not allowed because account is locked").
# Only the literal '*' is written; no password hash is read from the host.

# called by dracut: only included when requested
check() {
    return 255
}

# called by dracut
depends() {
    return 0
}

# called by dracut
install() {
    if ! grep -qs '^root:' "$initdir/etc/shadow"; then
        echo 'root:*:19000:0:99999:7:::' >> "$initdir/etc/shadow"
    fi
    chmod 0600 "$initdir/etc/shadow"
}
