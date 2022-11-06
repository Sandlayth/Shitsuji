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
  }
}
