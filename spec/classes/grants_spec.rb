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

  it {
    is_expected.to contain_postgresql__server__grant_role("pg_read_all_settings_to_#{params[:db_user]}")
      .with(group: 'pg_read_all_settings', role: params[:db_user])
  }

  it {
    is_expected.to contain_postgresql_psql("grant_role:pg_read_all_settings_to_#{params[:db_user]}")
      .with(command: "GRANT \"pg_read_all_settings\" TO \"#{params[:db_user]}\"")
  }
end
