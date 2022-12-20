# frozen_string_literal: true

require 'spec_helper'

describe 'pgbackrest::cron_backup' do
  let(:title) { 'namevar' }
  let(:params) do
    {
      id: 'psql01a',
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

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
