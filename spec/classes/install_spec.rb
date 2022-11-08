# frozen_string_literal: true

require 'spec_helper'

describe 'pgbackrest::install' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it {
        is_expected.to contain_package('pgbackrest').with_ensure(%r{present|installed})
      }
    end
  end
end
