# frozen_string_literal: true

require 'spec_helper'

describe 'profiles::secretmanager' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it {
        is_expected.to compile
        is_expected.to contain_file('/opt/')
          .with(ensure: 'directory')
          .with(owner: 'root')
          .with(group: 'root')
          .with(mode: '0755')
        is_expected.to contain_file('/opt/docker-compose/')
          .with(ensure: 'directory')
          .with(owner: 'root')
          .with(group: 'root')
          .with(mode: '0755')
          .with(require: 'File[/opt/]')
        is_expected.to contain_file('/opt/docker-compose/secretmanager/')
          .with(ensure: 'directory')
          .with(owner: 'root')
          .with(group: 'root')
          .with(mode: '0755')
          .with(require: 'File[/opt/docker-compose/]')
        is_expected.to contain_file('docker-compose-vault')
          .with(ensure: 'file')
          .with(owner: 'root')
          .with(group: 'root')
          .with(mode: '0644')
          .with(source: 'puppet:///modules/profiles/secretmanager/docker-compose.yml')
          .with(path: '/opt/docker-compose/secretmanager/docker-compose.yml')
          .with(require: 'File[/opt/docker-compose/secretmanager/]')
        is_expected.to contain_file('/vault/')
          .with(ensure: 'directory')
          .with(owner: 'root')
          .with(group: 'root')
          .with(mode: '0755')
        is_expected.to contain_file('/vault/config/')
          .with(ensure: 'directory')
          .with(owner: 'root')
          .with(group: 'root')
          .with(mode: '0755')
          .with(require: 'File[/vault/]')
        is_expected.to contain_file('vault-config')
          .with(ensure: 'file')
          .with(owner: 'root')
          .with(group: 'root')
          .with(mode: '0644')
          .with(source: 'puppet:///modules/profiles/secretmanager/vault.json')
          .with(path: '/vault/config/vault.json')
          .with(require: 'File[/vault/config/]')
        is_expected.to contain_docker_compose('hcp_vault')
          .with(ensure: 'present')
          .with(compose_files: ['/opt/docker-compose/secretmanager/docker-compose.yml'])
          .with(subscribe: [ 'File[docker-compose-vault]', 'File[vault-config]'])
        is_expected.to contain_firewall('100 allow 8200 to 192.168.0.0/16')
          .with(destination: '192.168.0.0/16')
          .with(source: '192.168.0.0/16')
          .with(dport: ['8200'])
          .with(proto: 'tcp')
          .with(action: 'accept')
      }
    end
  end
end
