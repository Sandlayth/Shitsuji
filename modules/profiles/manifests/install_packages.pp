# @summary Install the packages provided, picking the install method per entry
#
# `aur => true` installs from the AUR via `$aur_helper`; `command => ...`
# installs with an exec; otherwise the native provider is used (apt on Debian,
# pacman on Arch).
#
# @param packages Array of Hashes of packages
# @param aur_helper AUR helper used for `aur => true` entries
# @param aur_user Non-root user the AUR helper runs as (yay/makepkg refuse root)
#
# @example
#   profiles::install_packages { 'infra_tools':
#     packages => lookup('infra_tools'),
#   }
define profiles::install_packages (
  Array            $packages   = [],
  String           $aur_helper = 'yay',
  Optional[String] $aur_user   = undef,
) {
  $default_options = {
    ensure => 'installed',
  }
  $packages.each |$package| {
    if ($package['aur']) {
      $aur_run = $aur_user ? {
        undef   => {},
        default => { 'user' => $aur_user, 'environment' => ["HOME=/home/${aur_user}"] },
      }
      ensure_resource('exec', "install_${package['name']}", {
        'command' => "yes | ${aur_helper} -S --needed ${package['name']}",
        'path'    => ['/bin', '/usr/bin', '/usr/local/bin'],
        'unless'  => "pacman -Q ${package['name']}",
      } + $aur_run)
    } elsif ($package['command']) {
      ensure_resource('exec', "install_${package['name']}", $package - ['name', 'ensure', 'service', 'aur'])
    } else {
      ensure_packages($package['name'], $default_options + $package - ['service', 'aur'])
    }
    if ($package['service']) {
      service { $package['name']:
        * => $package['service'],
      }
    }
  }
}
