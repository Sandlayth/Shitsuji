# @summary Install Tailscale on DSM 7 and join the tailnet
#
# Idempotent: installs the official SPK only if missing, keeps the boot-time
# configure-host hook in place, and logs in only if the node is logged out.
# Without an auth key the plan returns the login URL to approve in a browser.
#
# @param targets Synology hosts
# @param version Tailscale SPK version from pkgs.tailscale.com
# @param arch DSM package arch (`synogetkeyvalue /etc.defaults/synoinfo.conf platform_name`)
# @param hostname Name of the node in the tailnet
# @param auth_key Optional pre-auth key; keep it out of the repo (e.g. `--params` from a prompt)
#
# @example
#   bolt plan run synology::tailscale -t futo
plan synology::tailscale (
  TargetSpec          $targets,
  String              $version  = '1.104.2',
  String              $arch     = 'armadaxp',
  Optional[String]    $hostname = undef,
  Sensitive[String]   $auth_key = Sensitive(''),
) {
  $cli     = '/var/packages/Tailscale/target/bin/tailscale'
  $rc_hook = '/usr/local/etc/rc.d/tailscale-configure-host.sh'

  get_targets($targets).each |$t| {
    # 1. Package
    $installed = run_command('/usr/syno/bin/synopkg version Tailscale', $t, '_catch_errors' => true)
    if !$installed.ok {
      # The SPK build number is not derivable from the version alone, so ask the
      # package index for the exact file name instead of guessing it.
      $find = run_command(
        "curl -fsSL https://pkgs.tailscale.com/stable/ | grep -o 'tailscale-${arch}-${version}-[0-9]*-dsm7.spk' | head -1",
        $t)
      $file = $find.first['stdout'].strip
      if $file.empty { fail_plan("No DSM7 SPK for ${arch} ${version} on pkgs.tailscale.com") }

      out::message("${t.name}: installing ${file}")
      run_command(@("CMD"/L), $t)
        set -e; cd /volume1/@tmp; \
        curl -fsSLO https://pkgs.tailscale.com/stable/${file}; \
        echo "$(curl -fsSL https://pkgs.tailscale.com/stable/${file}.sha256)  ${file}" | sha256sum -c -; \
        /usr/syno/bin/synopkg install ${file}; \
        rm -f ${file}
        | CMD
      run_command('/usr/syno/bin/synopkg start Tailscale', $t)
    }

    # 2. Boot hook + TUN/capabilities (needs a restart of the package to apply)
    # Pushed through the command channel: DSM ships with SFTP disabled, which
    # breaks upload_file over modern scp.
    $hook = base64('encode', file('synology/tailscale-configure-host.sh'), 'strict')
    run_command("echo ${hook} | base64 -d > ${rc_hook} && chmod 755 ${rc_hook}", $t)
    if !run_command('test -c /dev/net/tun', $t, '_catch_errors' => true).ok {
      run_command("${rc_hook} start", $t)
    }

    # 3. Login
    $status = run_command("${cli} status --json", $t, '_catch_errors' => true).first['stdout']
    $state  = $status =~ /"BackendState":\s*"Running"/
    if $state {
      out::message("${t.name}: already on the tailnet")
    } else {
      $name = pick($hostname, $t.name)
      # The key travels as an env var so it never lands in Bolt's command log.
      $env  = $auth_key.unwrap.empty ? { true => {}, default => { 'TS_KEY' => $auth_key.unwrap } }
      $key  = $auth_key.unwrap.empty ? { true => '', default => ' --auth-key="$TS_KEY"' }
      # `up` blocks until the login is approved; give it a few seconds to
      # register the URL, then read it back from the status JSON.
      run_command("${cli} up --hostname=${name} --accept-dns=false --timeout=15s${key}", $t,
        '_catch_errors' => true, '_env_vars' => $env)
      $after = run_command("${cli} status --json", $t).first['stdout']
      if $after =~ /"BackendState":\s*"Running"/ {
        out::message("${t.name}: joined the tailnet as ${name}")
      } else {
        $url = $after.match(/"AuthURL":\s*"([^"]+)"/)
        $msg = $url ? { undef => '(no URL yet, rerun the plan)', default => $url[1] }
        out::message("${t.name}: approve this node in your browser: ${msg}")
      }
    }
  }
}
