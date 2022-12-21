# frozen_string_literal: true

require 'spec_helper'

describe 'pgbackrest::cron_backup' do
  _, os_facts = on_supported_os.first
  let(:title) { 'psql' }
  let(:facts) { os_facts }
  let(:params) do
    {
      id: 'psql01a',
      repo: 1,
      cluster: 'psql01',
      host_group: 'common',
      backup_type: 'incr',
      server_address: 'localhost',
      db_name: 'backup',
      db_user: 'pgbackrest',
      backup_user: 'pgbackup',
      backup_dir: '/var/lib/pgbackrest',
    }
  end

  it { is_expected.to compile }

  it {
    expect(exported_resources).to contain_cron('pgbackrest_incr_localhost-common')
      .with(
        user: 'pgbackup',
        weekday: '*',
        hour: '4',
        minute: '0',
      )
  }
end
