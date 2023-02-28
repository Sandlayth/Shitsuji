# @summary Install and configure a DNS recursive server
#
# Install and configure a DNS recursive server with Docker
#
# @example
#   include profiles::dnsserver
class profiles::dnsserver(Boolean $enable_dhcp_server = false) {
  file { ['/opt', '/opt/docker-compose', '/opt/docker-compose/dnsserver/']:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    notify => File['docker-compose'],
  }

  file { 'docker-compose':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    path    => '/opt/docker-compose/dnsserver/docker-compose.yml',
    content => epp('profiles/dnsserver/docker-compose.yml.epp', {
        'enable_dhcp_server' => $enable_dhcp_server,
    })
  }

  docker_compose { 'pihole':
    ensure        => present,
    compose_files => ['/opt/docker-compose/dnsserver/docker-compose.yml'],
    subscribe     => File['docker-compose'],
  }

  firewall { '100 allow http to 192.168.0.0/16':
    source      => '192.168.0.0/16',
    destination => '192.168.0.0/16',
    dport       => ['1080'],
    proto       => 'tcp',
    action      => 'accept',
  }

  if $enable_dhcp_server {
    augeas{ "eth0_interface" :
      context => "/files/etc/network/interfaces",
      changes => [
        "set auto[child::1 = 'eth0']/1 eth0",
        "set iface[. = 'eth0'] eth0",
        "set iface[. = 'eth0']/family inet",
        "set iface[. = 'eth0']/method static",
        "set iface[. = 'eth0']/address 192.168.1.2",
        "set iface[. = 'eth0']/netmask 255.255.255.0",
      ]
    }
  }
}
