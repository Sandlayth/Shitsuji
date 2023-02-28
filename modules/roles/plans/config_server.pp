plan roles::config_server(
  TargetSpec $targets,
) {
  $targets.apply_prep
  apply($targets) {
    include profiles::users
    include profiles::base
    include profiles::dnsserver
    include profiles::secretmanager
  }
}
