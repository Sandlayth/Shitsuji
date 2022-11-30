# @summary Install and configure base tools
#
# @example
#   include profiles::base
class profiles::base {
  $packages = lookup('base_packages')

  $packages.each |$package| {
    package { default:
      ensure => 'present',
      ;
      $package['name']:
        * => $package,
    }
  }
}
