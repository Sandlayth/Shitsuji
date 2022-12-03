# @summary Install and configure base tools
#
# @example
#   include profiles::base
class profiles::base {
  $packages = lookup('base_packages')
  $default_options = {
      ensure => 'installed',
  }
  $packages.each |$package| {
    if ($package['command']) {
      ensure_resource('exec', "install_${package['name']}", $package - ['name', 'ensure'])
    } else {
      ensure_packages($package['name'], $default_options + $package)
    }
  }
}
