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
        is_expected.to contain_exec('dotfiles-clone-foo')
          .with(path: '/usr/bin')
          .with(command: 'git clone --bare test /home/foo/.dotfiles')
          .with(user: 'foo')
          .with(creates: '/home/foo/.dotfiles')
        is_expected.to contain_exec('dotfiles-pull-foo')
          .with(path: '/usr/bin')
          .with(command: 'git --git-dir=/home/foo/.dotfiles/ --work-tree=/home/foo pull')
          .with(user: 'foo')
          .with(onlyif: '/usr/bin/test -d /home/foo/.dotfiles')
      }
      it {
        is_expected.to contain_user('user-bar')
          .with(ensure: 'absent')
          .with(name: 'bar')
          .with(managehome: false)
          .with(shell: '/usr/bin/bash')
        is_expected.to contain_sudo__conf('sudo-bar')
          .with(ensure: 'absent')
        is_expected.not_to contain_exec('dotfiles-clone-bar')
        is_expected.not_to contain_exec('dotfiles-pull-bar')
      }
      it {
        is_expected.to contain_user('user-baz')
          .with(ensure: 'absent')
          .with(name: 'baz')
          .with(managehome: false)
          .with(shell: '/usr/bin/bash')
        is_expected.to contain_sudo__conf('sudo-baz')
          .with(ensure: 'absent')
        is_expected.not_to contain_exec('dotfiles-clone-baz')
        is_expected.not_to contain_exec('dotfiles-pull-baz')
      }
      it {
        is_expected.to contain_user('user-fuu')
          .with(ensure: 'present')
          .with(name: 'fuu')
          .with(managehome: true)
          .with(shell: '/usr/bin/bash')
        is_expected.to contain_sudo__conf('sudo-fuu')
          .with(ensure: 'absent')
        is_expected.not_to contain_exec('dotfiles-clone-fuu')
        is_expected.not_to contain_exec('dotfiles-pull-fuu')
      }
    end
  end
end
