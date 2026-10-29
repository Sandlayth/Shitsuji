# @summary Publish a local HTTP backend as a Tailscale Service over HTTPS
#
# The service gets its own tailnet IP, MagicDNS name and Let's Encrypt
# certificate (https://<name>.<tailnet>.ts.net), so it can move between hosts
# without changing its URL. Prerequisites in the admin console: HTTPS
# certificates enabled, the service defined (endpoint tcp:443), the host
# tagged and approved for it. The serve config persists in tailscaled's state.
#
# Host var `tailscale_cli`: path to the tailscale binary (default `tailscale`).
#
# @param targets Hosts serving it
# @param service Service name, e.g. `svc:vikunja`
# @param backend Local URL to proxy to, e.g. `http://127.0.0.1:3456`
# @param port HTTPS port of the service endpoint
#
# @example
#   bolt plan run tailnet::service -t futo service=svc:vikunja backend=http://127.0.0.1:3456
plan tailnet::service (
  TargetSpec        $targets,
  Pattern[/^svc:/]  $service,
  String            $backend,
  Integer           $port = 443,
) {
  get_targets($targets).each |$t| {
    $ts = $t.vars['tailscale_cli'].lest || { 'tailscale' }

    $status = run_command("${ts} serve status --json", $t).first['stdout']
    $config = $status.empty ? { true => {}, default => $status.parsejson }
    $proxy  = $config.dig('Services', $service, 'Web').then |$web| {
      $web.values.map |$w| { $w.dig('Handlers', '/', 'Proxy') }
    }
    if !($proxy and $backend in $proxy) {
      out::message("${t.name}: serving ${service} -> ${backend}")
      run_command("${ts} serve --service=${service} --https=${port} --bg --yes ${backend}", $t)
    }

    $suffix = run_command("${ts} status --json", $t).first['stdout'].parsejson['MagicDNSSuffix']
    out::message("${t.name}: ${service} at https://${service.regsubst(/^svc:/, '')}.${suffix}/")
  }
}
