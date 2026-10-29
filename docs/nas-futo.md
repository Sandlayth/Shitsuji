# NAS `futo` — engineering notes

Synology **DS214+** at `192.168.1.3`, studied and brought under Shitsuji on
2026-10-22 after ~2 years powered off. Managed with Bolt (`roles::nas`,
`modules/synology`); there is no Puppet agent on DSM.

## Hardware & OS

| | |
|---|---|
| SoC | Marvell Armada XP MV78230, 2 × ARMv7 @ 1.33 GHz, 1 GB RAM |
| SATA | Marvell 88SX7042 on PCIe (`11ab:7042`, `sata_mv`), 2 hot-swap bays |
| USB 3 | Etron EJ168 on PCIe (`1b6f:7023`) |
| LAN | 2 × GbE (`mv_eth`, Synology's out-of-tree driver); `eth0` used, `eth1` unplugged |
| Flash | 8 MB SPI: `RedBoot`(u-boot) / `zImage` / `rd.gz` / `vendor` / `RedBoot Config` / `FIS directory` |
| OS | DSM 7.1.1-42962 Update 5, kernel 3.2.101 — final DSM line for this model |

Flash dump (all six partitions, sha256-verified): `~/nas-futo-backup/flash/`
on the workstation. Keep it; it is the way back to stock firmware.

## Storage

`md0` (DSM system, RAID1) · `md1` (swap, RAID1) · `md2` → LVM `vg1` →
`volume_1` (ext4, 1.8 TB, ~64 % used). All standard Linux: any distro can
assemble and mount it (`mdadm --assemble --scan; vgchange -ay`).

- **Degraded since the array was built (Jan 2023).** Bay 1 (Seagate
  ST32000542AS) died: it reported a 4 GB "ST_M13FQBL" identity, failed every
  command and caused boot-time SATA reset storms. Removed 2026-10-22.
- Remaining disk: WD20EADS (Green), ~87 000 power-on hours, SMART clean.
  **Single copy of everything; no backup** (accepted risk for now).
- Shares: `music`, `photo`, `video`, `Shared downloads` (`backups/`, `to_keep/`).

## Findings and what was done

| Finding | Action |
|---|---|
| Nobody noticed the degraded array for ~3 years: no mail/push notifications | `synology::health` reports RAID/SMART/space/kernel errors/clock/Tailscale and fails on critical |
| Beeping (degraded volume) | `SYNO.Core.Hardware.BeepControl stop_beep` |
| Clock 22 min fast: `time.google.com` resolved to IPv6 only, LAN has no IPv6 | NTP → `nl.pool.ntp.org` (`synology::baseline`) |
| 11 unused packages loading a 1 GB ARM box | Stopped, persistently (`synology::baseline`) |
| No remote access | Tailscale (personal tailnet), `synology::tailscale` |
| System partition 2.4 GB at 88 % | Watch; do not install things on `/` |
| SSH allows passwords for users | Root is key-only; consider `PasswordAuthentication no` |

## The "NAS hangs" — resolved: Wi-Fi clients, not the NAS

Symptom: ping works, new TCP connections time out (even to closed ports),
established sessions survive; lasts minutes, per client.

Captured on the NAS, the affected SYNs carry a **wrong TCP checksum**, and the
kernel drops them (`Tcp: InErrs` +1 each). Only that field differs from what
the client sent; identical software-checksummed packets arrive with
*different* bad checksums. Evidence that it is not the NAS:

- During an episode of one client, another client connects fine.
- During an episode, 89/89 TCP packets from the router's own stack (wired)
  arrive with correct checksums through the same NIC, driver and kernel.
- NAS -> client packets are intact; client -> router TCP works.
- Not reproducible with memory/I/O pressure on the NAS.

Both affected clients have an **Intel BE200 Wi-Fi 7** card; corruption hits
TCP bridged from Wi-Fi to the wired side. Culprit (BE200 firmware/driver vs.
router bridging) not yet isolated. Cheap discriminators left: a non-BE200
Wi-Fi client (phone) during an episode, or a cabled client.

**Workaround in use:** clients reach the NAS over Tailscale. TCP travels inside
WireGuard (UDP), which is unaffected; SMB over the tailnet sustains
~17 MB/s (~140 Mbit/s), limited by the NAS CPU and NTFS-over-FUSE.

## Serving media

The NAS cannot host a media stack itself: Jellyfin 10.11 dropped 32-bit ARM,
LinuxServer *arr images ship no armhf, DSM has no Docker for this SoC (a 2023
`dockerd` core dump on `/volume1` shows an attempt), 1 GB RAM is soldered and
there is no transcoding. It serves the library as a file server instead.

- Share `usbshare2-2` (USB Seagate Expansion 4 TB, NTFS; `Media/` holds
  Movies 816 GB) is granted RW to the non-admin DSM account `media`
  (`synology::media_share`). Password: `~/nas-futo-backup/media-smb.cred`.
- That USB disk has **264 pending sectors**: failing. Plan: a new disk in bay
  1 as a separate media volume (the library does not fit on `volume1`,
  708 GB free).
- The same disk holds `nas/` (726 GB, an old copy of NAS data) and `old/`.

## Vikunja (todo lists)

`https://vikunja.tail9f3ba5.ts.net/`, tailnet only: Vikunja listens on
loopback (DSM's firewall is off, so `0.0.0.0` would also mean the LAN) and the
Tailscale Service `svc:vikunja` publishes it with its own tailnet IP and a
Let's Encrypt certificate (`tailnet::service`). Generic plan `vikunja`; the
NAS-specific bits are inventory vars. Account `yassine`, password in
`~/nas-futo-backup/vikunja.cred`.

DSM itself is published the same way: `svc:synology` ->
`https://synology.tail9f3ba5.ts.net/` (inventory `tailscale_services`). Both
need futo tagged `tag:server` and approved as the services' host.

- Installed in `/usr/local/vikunja` on the **system partition** (md0), not
  /volume1, so it keeps running if the data volume is rebuilt or replaced. md0
  is RAID1 across the data disks: it survives losing one disk only when there
  are two. Costs ~110 MB of `/` (now ~93 % used): watch it.
- **The official ARM builds cannot run here**, so `vikunja_source: build`
  compiles one locally (`vikunja::build`, needs go/node/zig):
  - they are UPX 5-packed and the stub needs `memfd_create`/`O_TMPFILE`
    (kernel >= 3.11; DSM is stuck on 3.2): instant SIGSEGV;
  - the PJ4B CPU has VFPv3 but **no NEON**; toolchains defaulting to NEON
    produce SIGILL in SQLite. The build targets `-mcpu=cortex_a9-neon`, musl
    static, no UPX.
- `/usr/local/etc/rc.d/vikunja.sh` starts it at boot under a small root loop
  that restarts it when it exits (also covers Tailscale not being up yet).
  Logs: `/usr/local/vikunja/data/vikunja.log`.
- **Backups**: `/etc/cron.d/vikunja-backup` (plain cron.d; DSM's `crond`
  reads it, no DSM API) runs `/usr/local/vikunja/backup.sh` nightly at 03:30:
  a `vikunja dump` zip (database as JSON, attachments, config) plus
  `secret.env` into `/volume1/backups/vikunja`, 14 days kept, log in
  `backup.log` there. Destination/retention/schedule are inventory vars.
  Restore (tested 2026-10-29 into a scratch instance):
  ```sh
  /usr/local/etc/rc.d/vikunja.sh stop
  cd /usr/local/vikunja/data && su -s /bin/sh nobody -c \
    '/usr/local/vikunja/vikunja --config /usr/local/vikunja/config.yml restore --preserve-config <zip>'
  # type: Yes, I understand
  /usr/local/etc/rc.d/vikunja.sh start
  ```
  /volume1 is on the **same single disk** as md0: this covers mistakes and a
  broken system partition, not a dead disk. Copy the dumps off the box too.

## Operating it

```sh
bolt plan run roles::nas -t nas          # converge + report
bolt plan run synology::health -t nas    # report only, non-zero exit on critical
bolt plan run synology::media_share -t nas share=usbshare2-2   # idempotent grant
bolt plan run vikunja -t futo version=vX.Y.Z   # upgrade (bump the default + sha256 in the plan)
```

From Wi-Fi clients, target the NAS over Tailscale (`100.86.101.69`) while the
checksum problem stands; LAN SSH may hang.

DSM quirks the plans account for: SFTP is disabled (files are pushed through
the command channel), `/tmp` is `noexec` (inventory `tmpdir: /volume1/@tmp`),
non-login `PATH` lacks `/usr/syno/bin` (absolute paths everywhere), DSM
settings go through `synowebapi`, never by editing generated files.

## Roadmap

- **Puppet on DSM (Entware + OpenVox gem): decided against.** DSM state must
  go through its own APIs anyway, and DSM is to be replaced.
- **Debian (path B).** Mainline has `armada-xp-synology-ds414.dts` (same SoC,
  same dual 88E1512 PHY mapping); a DS214+ variant is needed. Prior art:
  Doozan forum (bodhi's mvebu kernels, "Debian on Synology DS214").
  Needs a 3.3 V USB-serial adapter (6-pin header reachable without opening
  the case). Boot from a USB SSD first; DSM stays in flash.
  **Never `saveenv` on the stock u-boot**: its env overlaps the kernel in
  flash. Gains: current kernel and security updates, mainline `mvneta`
  instead of `mv_eth`, a normal Puppet-managed Debian host.
- **Disk**: a second disk restores redundancy; the rebuild reads the whole
  old disk, so it is also the riskiest moment for it.
