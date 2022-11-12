# frozen_string_literal: true

require 'spec_helper'

describe 'profiles::desktop' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:hiera_config) { 'hiera-rspec.yaml' }

      it { is_expected.to compile }
      it {
        is_expected.to contain_package('package_present')
          .with(name: 'package_present')
          .with(ensure: 'present')
        is_expected.to contain_package('package_absent')
          .with(name: 'package_absent')
          .with(ensure: 'absent')
        is_expected.to contain_package('package_options')
          .with(name: 'package_options')
          .with(ensure: 'present')
          .with(source: 'package_source')
      }
    end
  end
end
