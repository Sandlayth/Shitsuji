# @summary Install and configure base desktop tools
#
# @example
#   include profiles::desktop
class profiles::desktop {
  $desktop_packages = lookup('desktop_packages')
  $graphical_packages = lookup('graphical_packages')

  profiles::install_packages { 'desktop_packages':
    packages => $desktop_packages,
  }

  profiles::install_packages { 'graphical_packages':
    packages => $graphical_packages,
  }
}
