# frozen_string_literal: true

require 'spec_helper'

describe 'profiles::base' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:hiera_config) { 'hiera-rspec.yaml' }

      it { is_expected.to compile }
      it { is_expected.to contain_profiles__install_packages('core_tools') }
      it { is_expected.to contain_profiles__install_packages('dev_tools') }
      it { is_expected.to contain_profiles__install_packages('infra_tools') }
      it { is_expected.to contain_profiles__install_packages('security_tools') }
      it { is_expected.to contain_profiles__install_packages('net_tools') }
    end
  end
end
