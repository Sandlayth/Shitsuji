# @summary Dedicated unprivileged user for building and installing AUR packages
#
# yay/makepkg refuse to run as root, so AUR installs run as this user instead
# of a human account. It gets passwordless sudo scoped to pacman (the only step
# that needs root) rather than full admin rights.
#
# @param user Username for the AUR build account
# @param home Home directory (used as the build/cache location)
#
# @example
#   include profiles::aur
class profiles::aur (
  String               $user = 'aur',
  Stdlib::Absolutepath $home = '/home/aur',
) {
  include sudo

  user { $user:
    ensure     => present,
    home       => $home,
    managehome => true,
    shell      => '/usr/bin/bash',
    system     => true,
    comment    => 'AUR build user',
  }

  sudo::conf { "aur-${user}":
    content => "${user} ALL=(ALL) NOPASSWD: /usr/bin/pacman",
  }
}
