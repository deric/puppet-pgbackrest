# frozen_string_literal: true

require 'spec_helper'

describe 'pgbackrest::grants' do
  _, os_facts = on_supported_os.first

  let(:facts) { os_facts }

  let :pre_condition do
    'include postgresql::server'
  end

  shared_examples 'common backup grants' do
    let(:db_user) { params[:db_user] }
    let(:db_name) { params[:db_name] }

    it { is_expected.to compile }

    it {
      is_expected.to contain_postgresql__server__grant("pg_catalog_usage_to_#{db_user}").with(
        db: db_name,
        role: db_user,
        privilege: 'USAGE',
        object_type: 'SCHEMA',
        object_name: 'pg_catalog',
      )
    }

    it {
      is_expected.to contain_postgresql_psql("grant:pg_catalog_usage_to_#{db_user}").with(
        command: "GRANT USAGE ON SCHEMA \"pg_catalog\" TO \"#{db_user}\"",
        db: db_name,
      )
    }

    it {
      is_expected.to contain_postgresql__server__grant_role("pg_read_all_settings_to_#{db_user}")
        .with(group: 'pg_read_all_settings', role: db_user)
    }

    it {
      is_expected.to contain_postgresql_psql("grant_role:pg_read_all_settings_to_#{db_user}")
        .with(command: "GRANT \"pg_read_all_settings\" TO \"#{db_user}\"")
    }

    it {
      is_expected.to contain_postgresql__server__grant("current_setting-to-#{db_user}").with(
        db: db_name,
        role: db_user,
        privilege: 'EXECUTE',
        object_type: 'FUNCTION',
        object_name: ['pg_catalog', 'current_setting'],
        object_arguments: ['text'],
      )
    }

    it {
      is_expected.to contain_postgresql_psql("grant:current_setting-to-#{db_user}")
        .with(command: "GRANT EXECUTE ON FUNCTION pg_catalog.current_setting(text) TO \"#{db_user}\"")
    }

    it {
      is_expected.to contain_postgresql__server__grant("set_config-to-#{db_user}").with(
        db: db_name,
        role: db_user,
        privilege: 'EXECUTE',
        object_type: 'FUNCTION',
        object_name: ['pg_catalog', 'set_config'],
        object_arguments: ['text', 'text', 'boolean'],
      )
    }

    it {
      is_expected.to contain_postgresql_psql("grant:set_config-to-#{db_user}")
        .with(command: "GRANT EXECUTE ON FUNCTION pg_catalog.set_config(text,text,boolean) TO \"#{db_user}\"")
    }

    it {
      is_expected.to contain_postgresql__server__grant("pg_is_in_recovery-to-#{db_user}").with(
        db: db_name,
        role: db_user,
        privilege: 'EXECUTE',
        object_type: 'FUNCTION',
        object_name: ['pg_catalog', 'pg_is_in_recovery'],
      )
    }

    it {
      is_expected.to contain_postgresql_psql("grant:pg_is_in_recovery-to-#{db_user}")
        .with(command: "GRANT EXECUTE ON FUNCTION pg_catalog.pg_is_in_recovery() TO \"#{db_user}\"")
    }

    it {
      is_expected.to contain_postgresql__server__grant("pg_create_restore_point-to-#{db_user}").with(
        object_name: ['pg_catalog', 'pg_create_restore_point'],
        object_arguments: ['text'],
      )
    }

    it {
      is_expected.to contain_postgresql_psql("grant:pg_create_restore_point-to-#{db_user}")
        .with(command: "GRANT EXECUTE ON FUNCTION pg_catalog.pg_create_restore_point(text) TO \"#{db_user}\"")
    }

    it {
      is_expected.to contain_postgresql__server__grant("pg_switch_wal-to-#{db_user}").with(
        object_name: ['pg_catalog', 'pg_switch_wal'],
      )
    }

    it {
      is_expected.to contain_postgresql_psql("grant:pg_switch_wal-to-#{db_user}")
        .with(command: "GRANT EXECUTE ON FUNCTION pg_catalog.pg_switch_wal() TO \"#{db_user}\"")
    }

    it {
      is_expected.to contain_postgresql__server__grant("pg_last_wal_replay_lsn-to-#{db_user}").with(
        object_name: ['pg_catalog', 'pg_last_wal_replay_lsn'],
      )
    }

    it {
      is_expected.to contain_postgresql_psql("grant:pg_last_wal_replay_lsn-to-#{db_user}")
        .with(command: "GRANT EXECUTE ON FUNCTION pg_catalog.pg_last_wal_replay_lsn() TO \"#{db_user}\"")
    }

    it {
      is_expected.to contain_postgresql__server__grant("txid_current-to-#{db_user}").with(
        object_name: ['pg_catalog', 'txid_current'],
      )
    }

    it {
      is_expected.to contain_postgresql_psql("grant:txid_current-to-#{db_user}")
        .with(command: "GRANT EXECUTE ON FUNCTION pg_catalog.txid_current() TO \"#{db_user}\"")
    }

    it {
      is_expected.to contain_postgresql__server__grant("txid_current_snapshot-to-#{db_user}").with(
        object_name: ['pg_catalog', 'txid_current_snapshot'],
      )
    }

    it {
      is_expected.to contain_postgresql_psql("grant:txid_current_snapshot-to-#{db_user}")
        .with(command: "GRANT EXECUTE ON FUNCTION pg_catalog.txid_current_snapshot() TO \"#{db_user}\"")
    }

    it {
      is_expected.to contain_postgresql__server__grant("txid_snapshot_xmax-to-#{db_user}").with(
        object_name: ['pg_catalog', 'txid_snapshot_xmax'],
        object_arguments: ['txid_snapshot'],
      )
    }

    it {
      is_expected.to contain_postgresql_psql("grant:txid_snapshot_xmax-to-#{db_user}")
        .with(command: "GRANT EXECUTE ON FUNCTION pg_catalog.txid_snapshot_xmax(txid_snapshot) TO \"#{db_user}\"")
    }

    it {
      is_expected.to contain_postgresql__server__grant("pg_control_checkpoint-to-#{db_user}").with(
        object_name: ['pg_catalog', 'pg_control_checkpoint'],
      )
    }

    it {
      is_expected.to contain_postgresql_psql("grant:pg_control_checkpoint-to-#{db_user}")
        .with(command: "GRANT EXECUTE ON FUNCTION pg_catalog.pg_control_checkpoint() TO \"#{db_user}\"")
    }
  end

  context 'on PostgreSQL < 15 (pg_start_backup/pg_stop_backup)' do
    let(:params) do
      {
        db_user: 'backup',
        db_name: 'backup',
        version: '14',
      }
    end

    include_examples 'common backup grants'

    it {
      is_expected.to contain_postgresql__server__grant('pg_start_backup-to-backup').with(
        db: 'backup',
        role: 'backup',
        privilege: 'EXECUTE',
        object_type: 'FUNCTION',
        object_name: ['pg_catalog', 'pg_start_backup'],
        object_arguments: ['text', 'boolean', 'boolean'],
      )
    }

    it {
      is_expected.to contain_postgresql_psql('grant:pg_start_backup-to-backup')
        .with(command: 'GRANT EXECUTE ON FUNCTION pg_catalog.pg_start_backup(text,boolean,boolean) TO "backup"')
    }

    it {
      is_expected.to contain_postgresql__server__grant('pg_stop_backup-to-backup').with(
        object_name: ['pg_catalog', 'pg_stop_backup'],
        object_arguments: ['boolean', 'boolean'],
      )
    }

    it {
      is_expected.to contain_postgresql_psql('grant:pg_stop_backup-to-backup')
        .with(command: 'GRANT EXECUTE ON FUNCTION pg_catalog.pg_stop_backup(boolean,boolean) TO "backup"')
    }

    it { is_expected.not_to contain_postgresql__server__grant('pg_backup_start-to-backup') }
    it { is_expected.not_to contain_postgresql__server__grant('pg_backup_stop-to-backup') }
  end

  context 'on PostgreSQL >= 15 (pg_backup_start/pg_backup_stop)' do
    let(:params) do
      {
        db_user: 'backup',
        db_name: 'backup',
        version: '15',
      }
    end

    include_examples 'common backup grants'

    it {
      is_expected.to contain_postgresql__server__grant('pg_backup_start-to-backup').with(
        db: 'backup',
        role: 'backup',
        privilege: 'EXECUTE',
        object_type: 'FUNCTION',
        object_name: ['pg_catalog', 'pg_backup_start'],
        object_arguments: ['text', 'boolean'],
      )
    }

    it {
      is_expected.to contain_postgresql_psql('grant:pg_backup_start-to-backup')
        .with(command: 'GRANT EXECUTE ON FUNCTION pg_catalog.pg_backup_start(text,boolean) TO "backup"')
    }

    it {
      is_expected.to contain_postgresql__server__grant('pg_backup_stop-to-backup').with(
        object_name: ['pg_catalog', 'pg_backup_stop'],
        object_arguments: ['boolean'],
      )
    }

    it {
      is_expected.to contain_postgresql_psql('grant:pg_backup_stop-to-backup')
        .with(command: 'GRANT EXECUTE ON FUNCTION pg_catalog.pg_backup_stop(boolean) TO "backup"')
    }

    it { is_expected.not_to contain_postgresql__server__grant('pg_start_backup-to-backup') }
    it { is_expected.not_to contain_postgresql__server__grant('pg_stop_backup-to-backup') }
  end

  context 'on PostgreSQL 16' do
    let(:params) do
      {
        db_user: 'backup',
        db_name: 'backup',
        version: '16',
      }
    end

    include_examples 'common backup grants'

    it { is_expected.to contain_postgresql__server__grant('pg_backup_start-to-backup') }
    it { is_expected.to contain_postgresql__server__grant('pg_backup_stop-to-backup') }
  end

  context 'with a custom db_user and db_name' do
    let(:params) do
      {
        db_user: 'pgbackrest',
        db_name: 'pgbackup',
        version: '16',
      }
    end

    include_examples 'common backup grants'

    it {
      is_expected.to contain_postgresql__server__grant('current_setting-to-pgbackrest')
        .with(db: 'pgbackup', role: 'pgbackrest')
    }

    it {
      is_expected.to contain_postgresql_psql('grant:current_setting-to-pgbackrest')
        .with(command: 'GRANT EXECUTE ON FUNCTION pg_catalog.current_setting(text) TO "pgbackrest"')
    }
  end
end
