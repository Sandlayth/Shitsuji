# @summary Run Vikunja (todo lists) on a personal server
#
# Installs a static Vikunja build, runs it as `nobody` and keeps it running.
# The secret is generated on the host and never leaves it. Host specifics come
# from inventory vars, so the same plan serves a DSM box and a regular Linux
# server:
#
# - `vikunja_listen`: address to listen on (default `0.0.0.0:3456`). Who can
#   reach the app is decided here, e.g. a VPN address to keep it off the LAN
# - `vikunja_public_url`: URL users open (default `http://<target name>:<port>/`)
# - `vikunja_tailscale_service`: optional, e.g. `svc:vikunja`; publishes the
#   app as a Tailscale Service over HTTPS (tailnet::service). Pair it with a
#   loopback `vikunja_listen`
# - `vikunja_source`: `release` (default, official binary) or `build` (built
#   locally by vikunja::build, for hosts the official builds cannot run on)
# - `service_manager`: `systemd` (default) or `rc.d` (a boot script in
#   /usr/local/etc/rc.d, for DSM)
# - `staging_dir`: where downloads are unpacked (default `/var/tmp`)
#
# Idempotent: installs only when the version differs, restarts only when the
# binary, config or service definition changed, creates the account only if
# missing.
#
# @param targets Hosts to install on
# @param version Vikunja release tag
# @param sha256 SHA-256 of each official `linux-<arch>-full.zip`, checked against
#   the release GPG signature (key 7D06 1A4A A614 36B4 0713 D42E FF05 4DAC D908 493A) when bumping
# @param dir Install directory. On DSM keep it on the system partition so the
#   app survives the data volume being rebuilt or replaced
# @param timezone Default timezone for the server
# @param user Account to create on first run
# @param email Email of that account (no mailer is configured, it is only an identifier)
# @param password Password for a newly created account; pass it from a prompt or file, never the repo
#
# @example
#   bolt plan run vikunja -t futo password=$(cat ~/nas-futo-backup/vikunja.cred)
plan vikunja (
  TargetSpec           $targets,
  String               $version  = 'v2.7.1',
  Hash[String, String] $sha256   = {
    'amd64' => '2d0b64a477341977958067a42a32655b74f5e72e6eb02f57942faa19d9ee76ad',
    'arm64' => 'f9336d8918e99cfadb9ed6f58f8d1a2b30ed30f7393ca2b98dbb3c8abfbdfcfd',
    'arm-7' => 'fdb263356f2e558a8012935a1b103f8277e29ed7bf37cb5391fbf5ea1bd28873',
  },
  String               $dir      = '/usr/local/vikunja',
  String               $timezone = 'Europe/Amsterdam',
  String               $user     = 'yassine',
  String               $email    = 'yassine@futo.lan',
  Sensitive[String]    $password = Sensitive(''),
) {
  $bin = "${dir}/vikunja"
  # CLI calls run as nobody so SQLite files stay owned by the service user.
  $cli = "cd ${dir}/data && su -s /bin/sh nobody -c '${bin} --config ${dir}/config.yml"

  get_targets($targets).each |$t| {
    $listen     = $t.vars['vikunja_listen'].lest || { '0.0.0.0:3456' }
    $port       = $listen.split(':')[-1]
    $public_url = $t.vars['vikunja_public_url'].lest || { "http://${t.name}:${port}/" }
    $source     = $t.vars['vikunja_source'].lest || { 'release' }
    $manager    = $t.vars['service_manager'].lest || { 'systemd' }
    $staging    = $t.vars['staging_dir'].lest || { '/var/tmp' }
    # Where the plan itself checks the app is up
    $probe      = $listen ? { /^0\.0\.0\.0:/ => "127.0.0.1:${port}", default => $listen }

    $service = $manager ? {
      'rc.d'    => {
        'path'    => '/usr/local/etc/rc.d/vikunja.sh',
        'content' => epp('vikunja/rc.sh.epp', { 'dir' => $dir }),
        'mode'    => '755',
        'reload'  => 'true',
        'start'   => '/usr/local/etc/rc.d/vikunja.sh start',
        'restart' => '/usr/local/etc/rc.d/vikunja.sh restart',
        'logs'    => "tail -20 ${dir}/data/vikunja.log",
      },
      'systemd' => {
        'path'    => '/etc/systemd/system/vikunja.service',
        'content' => epp('vikunja/vikunja.service.epp', { 'dir' => $dir }),
        'mode'    => '644',
        'reload'  => 'systemctl daemon-reload && systemctl enable vikunja',
        'start'   => 'systemctl start vikunja',
        'restart' => 'systemctl restart vikunja',
        'logs'    => 'journalctl -u vikunja -n 20 --no-pager',
      },
      default   => fail_plan("${t.name}: unsupported service_manager '${manager}'"),
    }

    # 1. Binary
    $current = run_command("${bin} version 2>/dev/null | grep -qF ' ${version}'", $t, '_catch_errors' => true).ok
    if !$current {
      $arch = run_command('uname -m', $t).first['stdout'].strip ? {
        'x86_64'  => 'amd64',
        'aarch64' => 'arm64',
        /^armv7/  => 'arm-7',
        default   => undef,
      }
      unless $arch { fail_plan("${t.name}: no Vikunja build for this CPU") }
      out::message("${t.name}: installing Vikunja ${version} (${arch}, ${source})")
      run_command("mkdir -p ${staging} ${dir}", $t)
      if $source == 'build' {
        $local = run_plan('vikunja::build', 'version' => $version, 'arch' => $arch)
        upload_file($local, "${staging}/vikunja-${version}", $t)
        run_command(@("CMD"/L), $t)
          install -m 755 ${staging}/vikunja-${version} ${bin}.new && mv ${bin}.new ${bin} \
          && rm -f ${staging}/vikunja-${version}
          | CMD
      } else {
        $zip = "vikunja-${version}-linux-${arch}-full.zip"
        run_command(@("CMD"/L$), $t)
          set -e; tmp=${staging}/vikunja-${version}; rm -rf \$tmp; mkdir -p \$tmp; cd \$tmp; \
          curl -fsSLO https://dl.vikunja.io/vikunja/${version}/${zip}; \
          echo "${sha256[$arch]}  ${zip}" | sha256sum -c -; \
          if command -v unzip > /dev/null; then unzip -q ${zip}; else python3 -m zipfile -e ${zip} .; fi; \
          install -m 755 vikunja-${version}-linux-${arch} ${bin}.new && mv ${bin}.new ${bin}; \
          cd /; rm -rf \$tmp
          | CMD
      }
      run_command("${bin} version", $t)
    }

    # 2. Data dir and secret (root-only env file, read before dropping to nobody)
    run_command(@("CMD"/L$), $t)
      mkdir -p ${dir}/data/files && chown -R nobody:\$(id -gn nobody) ${dir}/data; \
      [ -s ${dir}/secret.env ] || (umask 077; \
        echo "VIKUNJA_SERVICE_SECRET=\$(head -c 48 /dev/urandom | base64 | tr -d '\n/+=')" > ${dir}/secret.env)
      | CMD

    # 3. Config and service definition, pushed through the command channel
    # (some hosts, like DSM, have SFTP off)
    $files = {
      "${dir}/config.yml" => [epp('vikunja/config.yml.epp', {
        'dir' => $dir, 'listen' => $listen, 'public_url' => $public_url, 'timezone' => $timezone,
      }), '644'],
      $service['path'] => [$service['content'], $service['mode']],
    }
    $changed = $files.map |$path, $spec| {
      $b64 = base64('encode', $spec[0], 'strict')
      run_command(@("CMD"/L), $t).first['stdout'] =~ /changed/
        echo ${b64} | base64 -d > ${path}.new && chmod ${spec[1]} ${path}.new; \
        if cmp -s ${path}.new ${path}; then rm ${path}.new; else mv ${path}.new ${path}; echo changed; fi
        | CMD
    }.any |$c| { $c }

    # 4. Service
    run_command($service['reload'], $t)
    if !$current or $changed {
      out::message("${t.name}: (re)starting Vikunja")
      run_command($service['restart'], $t)
    } else {
      run_command($service['start'], $t)
    }
    # The first start runs the migrations, slow on small ARM boards.
    run_command(@("CMD"/L$), $t)
      i=0; while [ \$i -lt 60 ]; do \
        curl -fsS http://${probe}/api/v1/info > /dev/null 2>&1 && exit 0; i=\$((i+1)); sleep 2; \
      done; ${service['logs']}; exit 1
      | CMD

    # 5. Account
    $users = run_command("${cli} user list'", $t).first['stdout']
    if $users !~ Regexp("\\b${user}\\b") {
      if $password.unwrap.empty { fail_plan("Vikunja user ${user} does not exist on ${t.name}; pass password= to create it") }
      out::message("${t.name}: creating Vikunja user ${user}")
      # The password travels as an env var so it never lands in Bolt's command log.
      run_command("${cli} user create -u ${user} -e ${email} -p \"\$VK_PW\"'", $t,
        '_env_vars' => { 'VK_PW' => $password.unwrap })
    }
    if $t.vars['vikunja_tailscale_service'] {
      run_plan('tailnet::service', 'targets' => $t,
        'service' => $t.vars['vikunja_tailscale_service'], 'backend' => "http://${probe}")
    }
    out::message("${t.name}: Vikunja at ${public_url}")
  }
}
