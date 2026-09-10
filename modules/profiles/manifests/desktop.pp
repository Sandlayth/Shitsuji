# @summary Install and configure desktop / graphical tooling
#
# @param tiers Package tiers to install for a desktop system
# @param aur_helper AUR helper passed through to install_packages
# @param aur_user Non-root user the AUR helper runs as
#
# @example
#   include profiles::desktop
class profiles::desktop (
  Array[String] $tiers = [
    'media_tools',
    'desktop_apps',
    'window_manager',
    'fonts',
  ],
  String           $aur_helper = lookup('aur_helper', { 'default_value' => 'yay' }),
  Optional[String] $aur_user   = lookup('aur_user', { 'default_value' => undef }),
) {
  if $facts['os']['family'] == 'Archlinux' and $aur_user {
    include profiles::aur
    Class['profiles::aur'] -> Profiles::Install_packages <| |>
  }

  $tiers.each |$tier| {
    profiles::install_packages { $tier:
      packages   => lookup($tier, { 'default_value' => [] }),
      aur_helper => $aur_helper,
      aur_user   => $aur_user,
    }
  }
}
