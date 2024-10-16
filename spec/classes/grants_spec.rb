# frozen_string_literal: true

require 'spec_helper'

describe 'pgbackrest::grants' do
  _, os_facts = on_supported_os.first

  let(:facts) { os_facts }

  let(:params) do
    {
      db_user: 'backup',
      db_name: 'backup',
      version: '16',
    }
  end

  let :pre_condition do
    'include postgresql::server'
  end

  it { is_expected.to compile }
end
