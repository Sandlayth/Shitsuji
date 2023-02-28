# @summary Install and configure a Secret Manager
#
# Install and configure Hashicorp Vault
#
# @example
#   include profiles::secretmanager
class profiles::secretmanager {
  file { ['/opt', '/opt/docker-compose', '/opt/docker-compose/secretmanager/']:
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
    path   => '/opt/docker-compose/secretmanager/docker-compose.yml',
    source => 'puppet:///modules/profiles/secretmanager/docker-compose.yml',
  }

  file { 'vault-config':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    path   => '/vault/config/vault.json',
    source => 'puppet:///modules/profiles/secretmanager/vault.json',
  }

  docker_compose { 'hcp_vault':
    ensure        => present,
    compose_files => ['/opt/docker-compose/secretmanager/docker-compose.yml'],
    subscribe     => [File['docker-compose'], File['vault-config']],
  }

  firewall { '100 allow http to 192.168.0.0/16':
    source      => '192.168.0.0/16',
    destination => '192.168.0.0/16',
    dport       => ['8200'],
    proto       => 'tcp',
    action      => 'accept',
  }
}
