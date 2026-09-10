# @summary Install and configure base (non-graphical) tooling
#
# @param tiers Package tiers to install for a base system
# @param aur_helper AUR helper passed through to install_packages
# @param aur_user Non-root user the AUR helper runs as
#
# @example
#   include profiles::base
class profiles::base (
  Array[String] $tiers = [
    'core_tools',
    'dev_tools',
    'infra_tools',
    'security_tools',
    'net_tools',
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
