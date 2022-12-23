# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tempfile'

describe 'pgbackrest::stanza' do
  _, os_facts = on_supported_os.first

  let(:facts) { os_facts }

  let :pre_condition do
    'include postgresql::server'
  end

  let(:params) do
    {
      version: '14',
    }
  end

  it { is_expected.to compile }

  it {
    is_expected.to contain_package('pgbackrest').with_ensure(%r{present|installed})
  }

  it { is_expected.to contain_class('pgbackrest::install') }

  context 'backup db' do
    let(:params) do
      {
        manage_dbuser: true,
        db_user: 'pgbackrest',
        db_name: 'pgbackup',
        version: '14',
      }
    end

    it {
      is_expected.to contain_postgresql__server__database('pgbackup').with(
        { 'owner' => 'pgbackrest' },
      )
    }

    it {
      is_expected.to contain_postgresql__server__role('pgbackrest').with(
        {
          'replication' => true,
          'superuser'   => false,
        },
      )
    }

    it { is_expected.to contain_class('pgbackrest::grants') }
  end

  context 'manage ssh keys' do
    let(:params) do
      {
        id: 'psql',
        manage_ssh_keys: true,
        ssh_key_type: 'ed25519',
        version: '14',
        db_path: '/var/lib/postgresql',
        backup_user: 'backup'
      }
    end

    it 'generates ssh key pair, if missing' do
      is_expected.to contain_exec('pgbackrest-generate-ssh-key_postgres').with(
        command: 'su - postgres -c "ssh-keygen -t ed25519 -q -N \'\' -f /var/lib/postgresql/.ssh/id_ed25519"',
      )
    end

    it {
      expect(exported_resources).to contain_ssh_authorized_key('postgres-psql.localhost')
        .with(
          user: 'backup',
          type: 'ssh-ed25519',
          key: 'AAAABBBBCC1lZDI1NTE5AAAAIN1UTKrM47QYBXJg0cIgrausN4o93I17AIj4K3i+5yS4',
          tag: ['pgbackrest-common'],
        )
    }

    it {
      is_expected.to contain_file('/var/cache/pgbackrest')
        .with(ensure: 'directory',
            owner: 'postgres',
            group: 'postgres')
    }

    it {
      is_expected.to contain_ini_setting('pgbackrest-stanza').with(
        {
          ensure: 'present',
          setting: 'postgres', value: '/var/lib/postgresql/.ssh/id_ed25519.pub',
          path: '/var/cache/pgbackrest/exported_keys.ini'
        },
      )
    }
  end

  context 'with plain text password' do
    let(:params) do
      {
        backups: {
          common: {
            incr: {},
          },
        },
        id: 'psql',
        port: 5433,
        db_name: 'pg_db',
        db_user:  'pg_user',
        db_password: 'TopSecret!',
        version: '14',
      }
    end

    it {
      expect(exported_resources).to contain_file_line('pgbackrest_pgpass_content-psql').with(
        line: 'psql.localhost:5433:pg_db:pg_user:TopSecret!',
      )
    }
  end

  context 'exporting host ssh key' do
    let(:params) do
      {
        id: 'psql',
        manage_host_keys: true,
        backup_dir: '/backup',
        version: '14',
      }
    end

    it {
      expect(exported_resources).to contain_sshkey('postgres-psql.localhost').with(
        ensure: 'present',
        target: '/backup/.ssh/known_hosts',
        key: 'AAAAE2VjZHNhLXNoYTBtbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBHSTDlBLg+FouBL5gEmO1PYmVNbguoZ5ECdIG/Acwt9SylhSAqZSlKKFojY3XwcTvokz/zfeVPesnNnBVgFWmXU=',
        tag: ['pgbackrest-common'],
      )
    }
  end

  context 'with backup schedule' do
    let(:params) do
      {
        backups: {
          common: {
            full: {},
          },
        },
        id: 'psql',
        manage_ssh_keys: false,
        manage_host_keys: false,
        version: '14',
      }
    end

    it {
      expect(exported_resources).to contain_exec('pgbackrest_stanza_create_psql.localhost-common').with(
        tag: 'pgbackrest_stanza_create-common',
        command: 'pgbackrest stanza-create --stanza=psql --log-level-console=warn'\
                 ' --pg1-host=psql.localhost --pg1-path=/var/lib/postgresql/14/main'\
                 ' --pg1-port=5432 --pg1-database=backup --pg1-user=backup --pg1-host-user=postgres',
      )
    }
  end
end
