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
        hostname: 'psql',
        manage_ssh_keys: true,
        ssh_key_type: 'ed25519',
        version: '14',
        db_path: '/var/lib/postgresql',
        user: 'pgbackup',
        ssh_user: 'pgbackup',
      }
    end

    it 'generates ssh key pair, if missing' do
      is_expected.to contain_exec('pgbackrest-generate-ssh-key_pgbackup').with(
        command: 'su - pgbackup -c "ssh-keygen -t ed25519 -q -N \'\' -f /home/pgbackup/.ssh/id_ed25519"',
      )
    end

    it {
      expect(exported_resources).to contain_ssh_authorized_key('pgbackup-psql.localhost')
        .with(
          user: 'pgbackup',
          type: 'ssh-ed25519',
          key: 'AAAAC3NzaC1lZDI1NTE5AAAAIN1UTKrM47QYBXJg0cIgrausN4o93I17AIj4K3i+5yS4',
          tag: ['pgbackrest-common'],
        )
    }

    it {
      is_expected.to contain_file('/var/cache/pgbackrest')
        .with(ensure: 'directory',
            owner: 'pgbackup',
            group: 'pgbackup')
    }

    it {
      is_expected.to contain_ini_setting('pgbackrest-stanza').with(
        {
          ensure: 'present',
          setting: 'pgbackup', value: '/home/pgbackup/.ssh/id_ed25519.pub',
          path: '/var/cache/pgbackrest/exported_keys.ini'
        },
      )
    }
  end

  context 'manage ssh keys with default ssh_user' do
    let(:params) do
      {
        hostname: 'psql',
        manage_ssh_keys: true,
        ssh_key_type: 'ed25519',
        version: '14',
        db_path: '/var/lib/postgresql',
      }
    end

    it 'generates the ssh key pair under the ssh_user home, not the backup user home' do
      is_expected.to contain_exec('pgbackrest-generate-ssh-key_postgres').with(
        command: 'su - postgres -c "ssh-keygen -t ed25519 -q -N \'\' -f /var/lib/postgresql/.ssh/id_ed25519"',
      )
    end

    it {
      is_expected.to contain_file('/var/lib/postgresql/.ssh')
        .with(ensure: 'directory',
            owner: 'postgres')
    }

    it {
      expect(exported_resources).to contain_ssh_authorized_key('postgres-psql.localhost')
        .with(
          user: 'pgbackup',
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
        hostname: 'psql',
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

  context 'with manage db user' do
    let(:params) do
      {
        backups: {
          common: {
            incr: {},
          },
        },
        hostname: 'psql',
        port: 5433,
        db_name: 'pg_db',
        db_user:  'pg_user',
        db_password: 'TopSecret!',
        version: '14',
        manage_dbuser: true,
      }
    end

    it {
      is_expected.to contain_postgresql__server__database('pg_db').with(
        { 'owner' => 'pg_user' },
      )
    }

    it {
      is_expected.to contain_postgresql__server__role('pg_user').with(
        {
          'replication' => true,
          'superuser'   => false,
        },
      )
    }
  end

  context 'archive_command' do
    context 'when manage_archive_cmd is enabled (default)' do
      let(:params) do
        {
          hostname: 'psql',
          version: '14',
        }
      end

      it {
        is_expected.to contain_postgresql__server__config_entry('archive_mode').with(
          value: 'on',
        )
      }

      it {
        is_expected.to contain_postgresql__server__config_entry('archive_command').with(
          value: 'pgbackrest --stanza=psql archive-push %p',
        )
      }
    end

    context 'with a custom cluster name' do
      let(:params) do
        {
          hostname: 'psql',
          cluster: 'main_cluster',
          version: '14',
        }
      end

      it {
        is_expected.to contain_postgresql__server__config_entry('archive_command').with(
          value: 'pgbackrest --stanza=main_cluster archive-push %p',
        )
      }
    end

    context 'when manage_archive_cmd is disabled' do
      let(:params) do
        {
          hostname: 'psql',
          manage_archive_cmd: false,
          version: '14',
        }
      end

      it { is_expected.not_to contain_postgresql__server__config_entry('archive_mode') }
      it { is_expected.not_to contain_postgresql__server__config_entry('archive_command') }
    end
  end

  context 'exporting host ssh key' do
    let(:params) do
      {
        hostname: 'psql',
        manage_host_keys: true,
        backup_dir: '/backup',
        version: '14',
      }
    end

    it {
      expect(exported_resources).to contain_sshkey('postgres-psql.localhost').with(
        ensure: 'present',
        target: '/backup/.ssh/known_hosts',
        key: 'AAAAC3NzaC1lZDI1NTE5AAAAIDeht9izXWL1PlUn5YFgLqBnKiUld/Kd+YSefOCqqsnQ',
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
        hostname: 'psql',
        db_user: 'pgbackup',
        manage_dbuser: true,
        manage_ssh_keys: false,
        manage_host_keys: false,
        version: '14',
      }
    end

    it { is_expected.to compile }

    it {
      expect(exported_resources).to contain_exec('pgbackrest_stanza_create_psql.localhost-common').with(
        tag: 'pgbackrest_stanza_create-common',
        command: 'pgbackrest stanza-create --stanza=psql',
        onlyif: "pgbackrest info --stanza=psql | grep -q 'missing stanza'",
      )
    }

    it {
      is_expected.to contain_postgresql__server__database('backup').with(
        { 'owner' => 'pgbackup' },
      )
    }
  end
end
