# @summary Install and configure base desktop tools
#
# @example
#   include profiles::desktop
class profiles::desktop {
  $packages = lookup('desktop_packages')
  $default_options = {
      ensure => 'present',
  }
  $packages.each |$package| {
    ensure_resource('package', $package['name'], $default_options + $package)
  }
}
