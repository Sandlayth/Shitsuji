# frozen_string_literal: true

require 'spec_helper'

describe 'profiles::dnsserver' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
      it {
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
        is_expected.to contain_file('/opt/docker-compose/dnsserver/')
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
          .with(source: 'puppet:///modules/profiles/dnsserver/docker-compose.yml')
          .with(path: '/opt/docker-compose/dnsserver/docker-compose.yml')
        is_expected.to contain_docker_compose('pihole')
          .with(ensure: 'present')
          .with(compose_files: ['/opt/docker-compose/dnsserver/docker-compose.yml'])
          .with(subscribe: 'File[docker-compose]')
      }
    end
  end
end
