# @summary Managed Thunderbird preferences (per user)
#
# Drops a managed user.js into each present user's *active* Thunderbird profile,
# enabling new-mail desktop notifications (sender + subject) through libnotify ->
# dunst. The profile directory name is random, so the $thunderbird_profiles fact
# resolves it from profiles.ini at apply time. A user with no Thunderbird profile
# is absent from the fact and simply gets no resource.
#
# @example
#   include profiles::thunderbird
class profiles::thunderbird {
  $users    = lookup('users').filter |$user| { $user['ensure'] == 'present' }
  $profiles = $facts['thunderbird_profiles']

  $users.each |$user| {
    $dir = $profiles =~ Hash ? {
      true    => $profiles[$user['name']],
      default => undef,
    }

    if $dir {
      file { "${dir}/user.js":
        ensure => file,
        owner  => $user['name'],
        group  => $user['name'],
        mode   => '0644',
        source => 'puppet:///modules/profiles/thunderbird/user.js',
      }
    }
  }
}
