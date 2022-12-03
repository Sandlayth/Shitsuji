# @summary Install and configure base tools
#
# @example
#   include profiles::base
class profiles::base {
  $packages = lookup('base_packages')
  $default_options = {
      ensure => 'present',
  }
  $packages.each |$package| {
    ensure_resource('package', $package['name'], $default_options + $package)
  }
}
