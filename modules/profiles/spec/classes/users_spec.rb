# frozen_string_literal: true

require 'spec_helper'

describe 'profiles::users' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:hiera_config) { 'hiera-rspec.yaml' }

      it { is_expected.to compile }
      it { is_expected.to contain_class('profiles::users') }
      it {
        is_expected.to contain_user('user-foo')
          .with(ensure: 'present')
          .with(name: 'foo')
          .with(managehome: true)
          .with(shell: '/usr/bin/bash')
      }
      it {
        is_expected.to contain_user('user-bar')
          .with(ensure: 'absent')
          .with(name: 'bar')
          .with(managehome: false)
          .with(shell: '/usr/bin/bash')
      }
    end
  end
end
