# frozen_string_literal: true

require 'spec_helper'

describe 'profiles::users' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:hiera_config) { 'hiera-rspec.yaml' }

      it { is_expected.to compile }
      it { is_expected.to contain_class('profiles::users') }
      it { is_expected.to contain_class('sudo') }
      it {
        is_expected.to contain_user('user-foo')
          .with(ensure: 'present')
          .with(name: 'foo')
          .with(managehome: true)
          .with(shell: '/usr/bin/bash')
        is_expected.to contain_sudo__conf('sudo-foo')
          .with(ensure: 'present')
          .with(content: 'foo ALL=(ALL) NOPASSWD: ALL')
      }
      it {
        is_expected.to contain_user('user-bar')
          .with(ensure: 'absent')
          .with(name: 'bar')
          .with(managehome: false)
          .with(shell: '/usr/bin/bash')
        is_expected.to contain_sudo__conf('sudo-bar')
          .with(ensure: 'absent')
      }
      it {
        is_expected.to contain_user('user-baz')
          .with(ensure: 'absent')
          .with(name: 'baz')
          .with(managehome: false)
          .with(shell: '/usr/bin/bash')
        is_expected.to contain_sudo__conf('sudo-baz')
          .with(ensure: 'absent')
      }
      it {
        is_expected.to contain_user('user-fuu')
          .with(ensure: 'present')
          .with(name: 'fuu')
          .with(managehome: true)
          .with(shell: '/usr/bin/bash')
        is_expected.to contain_sudo__conf('sudo-fuu')
          .with(ensure: 'absent')
      }
    end
  end
end
