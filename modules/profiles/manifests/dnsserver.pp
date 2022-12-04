# @summary Install and configure a DNS recursive server
#
# Install and configure a DNS recursive server with Docker
#
# @example
#   include profiles::dnsserver
class profiles::dnsserver {
  file { ['/opt', '/opt/docker-compose', '/opt/docker-compose/dnsserver/']:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    notify => File['docker-compose'],
  }

  file { 'docker-compose':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    source => 'puppet:///modules/profiles/dnsserver/docker-compose.yml',
    path   => '/opt/docker-compose/dnsserver/docker-compose.yml',
  }

  docker_compose { 'pihole':
    ensure        => present,
    compose_files => ['/opt/docker-compose/dnsserver/docker-compose.yml'],
    subscribe     => File['docker-compose'],
  }
}
