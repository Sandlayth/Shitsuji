# @summary Install the packages provided
#
# @param packages Array of Hashes of packages
#
# @example
#   include profiles::install_packages
define profiles::install_packages (Array $packages = []) {
  $default_options = {
    ensure => 'installed',
  }
  $packages.each |$package| {
    if ($package['command']) {
      ensure_resource('exec', "install_${package['name']}", $package - ['name', 'ensure','service'])
    } else {
      ensure_packages($package['name'], $default_options + $package - ['service'])
    }
    if ($package['service']) {
      service { $package['name']:
        * => $package['service'],
      }
    }
  }
}
