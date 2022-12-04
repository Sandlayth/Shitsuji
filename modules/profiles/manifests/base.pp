# @summary Install and configure base tools
#
# @example
#   include profiles::base
class profiles::base {
  $packages = lookup('base_packages')

  profiles::install_packages { 'base_packages':
    packages => $packages,
  }
}
