#!/usr/bin/env python3
"""Read-only health report for a Synology DSM box.

Emits one JSON document. Every check reports a `status` of ok/warn/crit so the
calling plan can summarise without knowing DSM internals. Stdlib only: DSM
ships a bare python3.
"""
import json
import os
import re
import subprocess
import time

PATH = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/syno/bin:/usr/syno/sbin:/usr/local/bin"


def sh(cmd, timeout=60):
    try:
        out = subprocess.run(
            cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            timeout=timeout, env={"PATH": PATH},
        )
        return out.stdout.decode(errors="replace")
    except subprocess.TimeoutExpired:
        return ""


def worst(statuses):
    for s in ("crit", "warn"):
        if s in statuses:
            return s
    return "ok"


def check_raid():
    arrays = {}
    mdstat = open("/proc/mdstat").read()
    for name, members, state in re.findall(r"^(md\d+) : \S+ \S+ (.*?)\n\s+\d+ blocks.*?\[\d+/\d+\] \[([U_]+)\]", mdstat, re.M):
        degraded = "_" in state
        arrays[name] = {
            "members": members.split(),
            "state": state,
            "status": "crit" if degraded else "ok",
        }
    return {"arrays": arrays, "status": worst([a["status"] for a in arrays.values()])}


SMART_ATTRS = {
    "5": "reallocated", "9": "power_on_hours", "187": "reported_uncorrect",
    "194": "temperature", "197": "pending", "198": "offline_uncorrectable",
    "199": "udma_crc",
}


def check_disks():
    disks = {}
    for dev in sorted(d for d in os.listdir("/dev") if re.fullmatch(r"sd[a-z]", d)):
        out = sh("smartctl -H -A -i -d sat /dev/%s" % dev)
        model = re.search(r"Device Model:\s+(.*)", out)
        health = re.search(r"overall-health self-assessment test result: (\S+)", out)
        attrs = {}
        for line in out.splitlines():
            f = line.split()
            if f and f[0] in SMART_ATTRS and len(f) >= 10:
                attrs[SMART_ATTRS[f[0]]] = int(re.match(r"\d+", f[9]).group())
        status = "ok"
        if not health or health.group(1) != "PASSED":
            status = "crit"
        elif any(attrs.get(k, 0) > 0 for k in ("pending", "offline_uncorrectable", "reported_uncorrect")):
            status = "crit"
        elif attrs.get("reallocated", 0) > 0 or attrs.get("power_on_hours", 0) > 50000:
            status = "warn"
        disks[dev] = {
            "model": model.group(1).strip() if model else None,
            "smart": health.group(1) if health else "UNREADABLE",
            "attrs": attrs,
            "status": status,
        }
    return {"disks": disks, "status": worst([d["status"] for d in disks.values()])}


def check_space():
    mounts = {}
    for mnt in ["/"] + sorted(m for m in os.listdir("/") if re.fullmatch(r"volume\d+", m)):
        path = mnt if mnt == "/" else "/" + mnt
        st = os.statvfs(path)
        pct = round(100 * (1 - st.f_bavail / st.f_blocks), 1)
        status = "crit" if pct >= 95 else "warn" if pct >= 85 else "ok"
        mounts[path] = {"used_pct": pct, "free_gb": round(st.f_bavail * st.f_frsize / 1e9, 1), "status": status}
    return {"mounts": mounts, "status": worst([m["status"] for m in mounts.values()])}


def check_kernel_errors():
    out = sh("dmesg")
    ata = len(re.findall(r"ata\d+(\.\d+)?: (exception|hard resetting|failed command)", out))
    io = len(re.findall(r"I/O error", out))
    hung = len(re.findall(r"blocked for more than", out))
    status = "crit" if hung or io else "warn" if ata else "ok"
    return {"ata_events": ata, "io_errors": io, "hung_tasks": hung, "status": status}


def check_time():
    out = sh("ntpq -pn", timeout=15)
    reachable = [l for l in out.splitlines()[2:] if l.split() and l.split()[6:7] != ["0"]]
    return {
        "epoch": time.time(),
        "ntp_peers_reachable": len(reachable),
        "status": "ok" if reachable else "warn",
    }


def check_tailscale():
    cli = "/var/packages/Tailscale/target/bin/tailscale"
    if not os.path.exists(cli):
        return {"installed": False, "status": "warn"}
    try:
        st = json.loads(sh(cli + " status --json", timeout=20))
        state = st.get("BackendState")
        ips = (st.get("Self") or {}).get("TailscaleIPs") or []
    except ValueError:
        state, ips = "unknown", []
    return {"installed": True, "state": state, "ips": ips, "status": "ok" if state == "Running" else "warn"}


def main():
    checks = {}
    for name, fn in [("raid", check_raid), ("disks", check_disks), ("space", check_space),
                     ("kernel", check_kernel_errors), ("time", check_time), ("tailscale", check_tailscale)]:
        try:
            checks[name] = fn()
        except Exception as e:  # one broken probe must not hide the others
            checks[name] = {"error": str(e), "status": "warn"}
    load = open("/proc/loadavg").read().split()[:3]
    uptime = float(open("/proc/uptime").read().split()[0])
    print(json.dumps({
        "status": worst([c["status"] for c in checks.values()]),
        "uptime_hours": round(uptime / 3600, 1),
        "load": load,
        "dsm": dict(re.findall(r'^(productversion|buildnumber|smallfixnumber)="(.*)"',
                               open("/etc.defaults/VERSION").read(), re.M)),
        "checks": checks,
    }))


main()
