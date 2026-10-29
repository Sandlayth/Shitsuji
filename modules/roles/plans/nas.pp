plan roles::nas(
  TargetSpec $targets,
) {
  # DSM has no Puppet agent (yet), so this role is pure Bolt: converge the
  # appliance through its own APIs, then report health.
  run_plan('synology::baseline', 'targets' => $targets)
  run_plan('synology::tailscale', 'targets' => $targets)
  run_plan('vikunja', 'targets' => $targets)
  # Host var `tailscale_services`: { 'svc:<name>' => '<local backend URL>' }
  get_targets($targets).each |$t| {
    ($t.vars['tailscale_services'].lest || { {} }).each |$service, $backend| {
      run_plan('tailnet::service', 'targets' => $t, 'service' => $service, 'backend' => $backend)
    }
  }
  run_plan('synology::health', 'targets' => $targets)
}
