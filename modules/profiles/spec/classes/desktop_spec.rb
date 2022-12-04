# frozen_string_literal: true

require 'spec_helper'

describe 'profiles::desktop' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:hiera_config) { 'hiera-rspec.yaml' }

      it { is_expected.to compile }
      it { is_expected.to contain_profiles__install_packages('desktop_packages') }
    end
  end
end
