# frozen_string_literal: true

require 'spec_helper'

describe 'profiles::secretmanager' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it {
        is_expected.to compile
        is_expected.to contain_file('/opt')
          .with(ensure: 'directory')
          .with(owner: 'root')
          .with(group: 'root')
          .with(mode: '0755')
          .with(notify: 'File[docker-compose]')
        is_expected.to contain_file('/opt/docker-compose')
          .with(ensure: 'directory')
          .with(owner: 'root')
          .with(group: 'root')
          .with(mode: '0755')
          .with(notify: 'File[docker-compose]')
        is_expected.to contain_file('/opt/docker-compose/secretmanager/')
          .with(ensure: 'directory')
          .with(owner: 'root')
          .with(group: 'root')
          .with(mode: '0755')
          .with(notify: 'File[docker-compose]')
        is_expected.to contain_file('docker-compose')
          .with(ensure: 'file')
          .with(owner: 'root')
          .with(group: 'root')
          .with(mode: '0644')
          .with(source: 'puppet:///modules/profiles/secretmanager/docker-compose.yml')
          .with(path: '/opt/docker-compose/secretmanager/docker-compose.yml')
        is_expected.to contain_file('vault-config')
          .with(ensure: 'file')
          .with(owner: 'root')
          .with(group: 'root')
          .with(mode: '0644')
          .with(source: 'puppet:///modules/profiles/secretmanager/vault.json')
          .with(path: '/vault/config/vault.json')
        is_expected.to contain_docker_compose('hcp_vault')
          .with(ensure: 'present')
          .with(compose_files: ['/opt/docker-compose/secretmanager/docker-compose.yml'])
          .with(subscribe: [ 'File[docker-compose]', 'File[vault-config]'])
        is_expected.to contain_firewall('100 allow http to 192.168.0.0/16')
          .with(destination: '192.168.0.0/16')
          .with(source: '192.168.0.0/16')
          .with(dport: ['8200'])
          .with(proto: 'tcp')
          .with(action: 'accept')
      }
    end
  end
end
