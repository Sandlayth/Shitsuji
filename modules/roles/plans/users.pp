plan roles::users(
  TargetSpec $targets,
) {
  $targets.apply_prep
  apply($targets) {
    include profiles::users
  }
}
