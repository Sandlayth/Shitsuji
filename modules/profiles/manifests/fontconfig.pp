# @summary System-wide fontconfig defaults
#
# Provides readable, *overridable* Arabic defaults and removes a stray rule
# that force-assigned a single Arabic font (overriding every per-user and
# per-application choice). Each user's ~/.config/fontconfig can still override
# the defaults set here.
#
# @example
#   include profiles::fontconfig
class profiles::fontconfig {
  # Stray rule that did mode="assign" (hard replace) on all Arabic text, which
  # beat every per-user/per-app font choice. Remove it so defaults are sane.
  file { '/etc/fonts/conf.d/65-noto-arabic.conf':
    ensure => absent,
  }

  # Overridable per-generic Arabic default (loads before per-user config at 50).
  file { '/etc/fonts/conf.d/45-arabic-readable.conf':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    source => 'puppet:///modules/profiles/fontconfig/45-arabic-readable.conf',
  }

  exec { 'fc-cache-refresh':
    command     => 'fc-cache -f',
    path        => ['/usr/bin', '/bin'],
    refreshonly => true,
    subscribe   => [
      File['/etc/fonts/conf.d/45-arabic-readable.conf'],
      File['/etc/fonts/conf.d/65-noto-arabic.conf'],
    ],
  }
}
