# @summary Install and configure a Secret Manager
#
# Install and configure Hashicorp Vault
#
# @example
#   include profiles::secretmanager
class profiles::secretmanager {
  ensure_resources('file', {
    '/opt/' => {
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    },
    '/opt/docker-compose/' => {
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
      require => File['/opt/'],
    },
    '/opt/docker-compose/secretmanager/' => {
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      require => File['/opt/docker-compose/'],
    },
    'docker-compose-vault' => {
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      path    => '/opt/docker-compose/secretmanager/docker-compose.yml',
      source  => 'puppet:///modules/profiles/secretmanager/docker-compose.yml',
      require => File['/opt/docker-compose/secretmanager/'],
    },
    '/vault/' => {
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    },
    '/vault/config/' => {
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      require => File['/vault/'],
    },
    'vault-config' => {
      ensure => file,
      owner  => 'root',
      group  => 'root',
      mode   => '0644',
      path   => '/vault/config/vault.json',
      source => 'puppet:///modules/profiles/secretmanager/vault.json',
      require => File['/vault/config/'],
    }
  })

  docker_compose { 'hcp_vault':
    ensure        => present,
    compose_files => ['/opt/docker-compose/secretmanager/docker-compose.yml'],
    subscribe     => [File['docker-compose-vault'], File['vault-config']],
  }

  firewall { '100 allow 8200 to 192.168.0.0/16':
    source      => '192.168.0.0/16',
    destination => '192.168.0.0/16',
    dport       => ['8200'],
    proto       => 'tcp',
    action      => 'accept',
  }
}
