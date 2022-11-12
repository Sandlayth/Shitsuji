# @summary Install and configure base desktop tools
#
# @example
#   include profiles::desktop
class profiles::desktop {
  $packages = lookup('desktop_packages')

  $packages.each |$package| {
    package { default:
      ensure => 'present',
      ;
      $package['name']:
        * => $package,
    }
  }
}
