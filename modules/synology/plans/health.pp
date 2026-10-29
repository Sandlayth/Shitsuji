# @summary Report the health of Synology hosts; fails if any check is critical
#
# Wraps the synology::health task and adds clock drift measured against the
# machine running Bolt. Meant to be run on a schedule from a workstation so a
# degraded array never goes unnoticed again.
#
# @param targets Synology hosts
# @param max_drift Seconds of clock drift tolerated before warning
#
# @example
#   bolt plan run synology::health -t nas
plan synology::health (
  TargetSpec $targets,
  Integer    $max_drift = 30,
) {
  $results = run_task('synology::health', $targets, '_catch_errors' => true)

  $reports = $results.map |$r| {
    if !$r.ok {
      out::message("${r.target.name}: UNREACHABLE (${r.error.message})")
      ({ 'target' => $r.target.name, 'status' => 'crit', 'unreachable' => true })
    } else {
      $drift = (Integer(Timestamp.new.strftime('%s')) - Integer($r['checks']['time']['epoch'])).abs
      $time_status = $drift > $max_drift ? { true => 'warn', default => $r['checks']['time']['status'] }

      $lines = $r['checks'].map |$name, $c| {
        $detail = $c['error'] ? {
          String  => "probe failed: ${c['error']}",
          default => $name ? {
          'raid'     => $c['arrays'].map |$md, $a| { "${md}=${a['state']}" }.join(' '),
          'disks'     => $c['disks'].map |$d, $i| { "${d}:${i['model']}:${i['smart']}" }.join(' '),
          'space'     => $c['mounts'].map |$m, $i| { "${m}=${i['used_pct']}%" }.join(' '),
          'kernel'    => "ata=${c['ata_events']} io=${c['io_errors']} hung=${c['hung_tasks']}",
          'time'      => "drift=${drift}s ntp_peers=${c['ntp_peers_reachable']}",
          'tailscale' => "${c['state']} ${c['ips']}",
          default     => '',
          },
        }
        $status = $name ? { 'time' => $time_status, default => $c['status'] }
        "  [${status}] ${name}: ${detail}"
      }
      out::message("${r.target.name}: ${r['status'].upcase} (DSM ${r['dsm']['productversion']}-${r['dsm']['buildnumber']} u${r['dsm']['smallfixnumber']}, up ${r['uptime_hours']}h, load ${r['load'].join(' ')})\n${lines.join("\n")}")
      $r.value + { 'target' => $r.target.name, 'clock_drift_s' => $drift }
    }
  }

  if $reports.any |$rep| { $rep['status'] == 'crit' } {
    fail_plan('At least one Synology host is in a critical state', 'synology/health-critical', { 'reports' => $reports })
  }
  return $reports
}
