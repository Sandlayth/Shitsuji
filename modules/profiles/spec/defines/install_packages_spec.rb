# frozen_string_literal: true

require 'spec_helper'

describe 'profiles::install_packages' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:title) { 'test_packages' }
      let(:params) do
        {
          'packages' => [
            {
              'name': 'package_present'
            },
            {
              'name': 'package_service',
              'service': {
                'ensure': 'running',
                'enable': 'true'
              }
            },
            {
              'name': 'package_absent',
              'ensure': 'absent'
            },
            {
              'name': 'package_options',
              'ensure': 'present',
              'source': 'package_source'
            },
            {
              'name': 'package_cmd',
              'command': '/usr/bin/test'
            },
          ]
        }
      end
      let(:facts) { os_facts }

      it { is_expected.to compile }
      it {
        is_expected.to contain_package('package_present')
          .with(name: 'package_present')
          .with(ensure: 'installed')
        is_expected.to contain_package('package_service')
          .with(name: 'package_service')
          .with(ensure: 'installed')
        is_expected.to contain_package('package_absent')
          .with(name: 'package_absent')
          .with(ensure: 'absent')
        is_expected.to contain_package('package_options')
          .with(name: 'package_options')
          .with(ensure: 'installed')
          .with(source: 'package_source')
        is_expected.to contain_exec('install_package_cmd')
          .with(command: '/usr/bin/test')
        is_expected.to contain_service('package_service')
          .with(ensure: 'running')
          .with(enable: 'true')
      }
    end
  end
end
