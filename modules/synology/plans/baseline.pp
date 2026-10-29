# @summary Converge DSM settings that matter for a small, quiet NAS
#
# Goes through DSM's own APIs/CLIs (synowebapi, synopkg) rather than editing
# files DSM regenerates. Every step reads the current state first, so a run
# with nothing to change changes nothing.
#
# @param targets Synology hosts
# @param ntp_server NTP server. Must resolve to IPv4: DSM's ntpd picks AAAA
#   records first (time.google.com does) and the LAN has no IPv6 route.
# @param stopped_packages Packages kept stopped (reversible with `synopkg start`)
#
# @example
#   bolt plan run synology::baseline -t nas
plan synology::baseline (
  TargetSpec    $targets,
  String        $ntp_server = 'nl.pool.ntp.org',
  Array[String] $stopped_packages = [
    'VideoStation',    # depends on CodecPack, stop it first
    'CodecPack',
    'MediaServer',
    'SynoFinder',      # Universal Search indexer
    'AntiVirus',
    'ActiveInsight',
    'StorageAnalyzer',
    'DownloadStation',
    'ScsiTarget',
    'CloudSync',
    'USBCopy',
  ],
) {
  $api = '/usr/syno/bin/synowebapi --exec'

  get_targets($targets).each |$t| {
    # NTP
    $ntp = run_command("${api} api=SYNO.Core.Region.NTP method=get version=1 2>/dev/null", $t).first['stdout'].parsejson
    if $ntp['data']['server'] != $ntp_server or $ntp['data']['enable_ntp'] != 'ntp' {
      out::message("${t.name}: NTP ${ntp['data']['server']} -> ${ntp_server}")
      # v2 `set` rejects partial input (error 5701); v1 accepts it.
      run_command("${api} api=SYNO.Core.Region.NTP method=set version=1 enable_ntp='\"ntp\"' server='\"${ntp_server}\"' timezone='\"${ntp['data']['timezone']}\"'", $t)
      run_command("${api} api=SYNO.Core.Region.NTP method=sync version=1 server='\"${ntp_server}\"'", $t)
    }

    # Packages
    $stopped_packages.each |$pkg| {
      $st = run_command("/usr/syno/bin/synopkg status ${pkg}", $t, '_catch_errors' => true).first['stdout']
      if $st =~ /"status":"running"/ {
        out::message("${t.name}: stopping ${pkg}")
        run_command("/usr/syno/bin/synopkg stop ${pkg}", $t)
      }
    }
  }
}
