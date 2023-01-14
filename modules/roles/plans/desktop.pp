plan roles::desktop(
  TargetSpec $targets,
) {
  $targets.apply_prep
  apply($targets) {
    include profiles::users
    include profiles::base
    include profiles::desktop
  }
}
