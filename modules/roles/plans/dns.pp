plan roles::dns(
  TargetSpec $targets,
) {
  $targets.apply_prep
  apply($targets) {
    include profiles::users
    include profiles::base
    include profiles::dnsserver
  }
}
