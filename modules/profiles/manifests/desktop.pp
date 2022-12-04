# @summary Install and configure base desktop tools
#
# @example
#   include profiles::desktop
class profiles::desktop {
  $packages = lookup('desktop_packages')

  profiles::install_packages { 'desktop_packages':
    packages => $packages,
  }
}
