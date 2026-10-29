#!/bin/sh
# Managed by Shitsuji (synology::tailscale). DSM runs /usr/local/etc/rc.d/*.sh
# with "start" at boot. DSM 7 runs Tailscale unprivileged; configure-host
# creates /dev/net/tun and grants the capabilities it needs, and must be
# re-applied after every boot.
case "$1" in
  start)
    /var/packages/Tailscale/target/bin/tailscale configure-host \
      && /usr/syno/bin/synopkg restart Tailscale
    ;;
esac
