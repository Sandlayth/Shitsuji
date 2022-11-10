# @summary Manage users and their configurations
#
# Manage users creation, rights, and install their dotfile using the bare
# repository and alias method (https://news.ycombinator.com/item?id=11071754)
#
# @example
#   include profiles::users
class profiles::users {
  class { 'sudo': }

  $users = lookup('users')

  $users.each |$user| {
    user { "user-${user['name']}":
      ensure     => $user['ensure'],
      name       => $user['name'],
      managehome => $user['ensure'] == 'present', # never deletes home
      shell      => $user['shell'],
    }
    $ensure_sudo = $user['admin'] ? {
      true    => $user['ensure'],
      default => 'absent',
    }
    sudo::conf { "sudo-${user['name']}":
      ensure  => $ensure_sudo,
      content => "${user['name']} ALL=(ALL) NOPASSWD: ALL",
    }
    if $user['ensure'] == 'present' and $user['dotfiles'] != undef {
      $home = "/home/${user['name']}"

      exec { "dotfiles-clone-${user['name']}":
        path    => '/usr/bin',
        command => "git clone --bare ${user['dotfiles']} ${home}/.dotfiles",
        user    => $user['name'],
        creates => "${home}/.dotfiles",
        require => User["user-${user['name']}"],
      }
      exec { "dotfiles-pull-${user['name']}":
        path    => '/usr/bin',
        command => "git --git-dir=${home}/.dotfiles/ --work-tree=${home} pull",
        user    => $user['name'],
        onlyif  => "/usr/bin/test -d ${home}/.dotfiles",
      }
    }
  }
}
