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

  context 'with global options' do
    let(:params) do
      {
        version: '14',
        config: {
          'global' => {
            'archive-async' => 'y',
            'process-max' => 8,
          },
        },
      }
    end

    it { is_expected.to compile }

    it {
      is_expected.to contain_ini_setting('global archive-async').with(
        ensure: 'present',
        path: '/etc/pgbackrest/pgbackrest.conf',
        section: 'global',
        setting: 'archive-async',
        value: 'y',
      )
    }

    it {
      is_expected.to contain_ini_setting('global process-max').with(
        ensure: 'present',
        path: '/etc/pgbackrest/pgbackrest.conf',
        section: 'global',
        setting: 'process-max',
        value: 8,
      )
    }
  end

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
        id: 1,
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
      expect(exported_resources).to contain_cron('pgbackrest_full_psql.localhost-common').with(
        tag: 'pgbackrest-common',
      )
    }

    it 'exports member config for the repository' do
      expect(exported_resources).to contain_file('/etc/pgbackrest/conf.d/psql-1.conf')
        .with(tag: ['pgbackrest-common'])
        .with_content(%r{\[psql\]})
        .with_content(%r{pg1-host = psql\.localhost})
        .with_content(%r{pg1-host-user = postgres})
        .with_content(%r{pg1-path = /var/lib/postgresql/14/main})
        .with_content(%r{pg1-port = 5432})
    end

    it 'keeps pg-host out of the local config' do
      is_expected.to contain_file('/etc/pgbackrest/conf.d/psql.conf')
        .with_content(%r{pg1-path = /var/lib/postgresql/14/main})
        .without_content(%r{pg1-host})
    end

    it {
      is_expected.to contain_postgresql__server__database('backup').with(
        { 'owner' => 'pgbackup' },
      )
    }
  end

  context 'standby replica' do
    let(:params) do
      {
        backups: {
          common: {
            incr: {},
          },
        },
        hostname: 'psql2',
        cluster: 'psql',
        id: 2,
        version: '14',
      }
    end

    it { is_expected.to compile }

    it 'exports member config with its own pg index' do
      expect(exported_resources).to contain_file('/etc/pgbackrest/conf.d/psql-2.conf')
        .with(tag: ['pgbackrest-common'])
        .with_content(%r{\[psql\]})
        .with_content(%r{pg2-host = psql\.localhost})
        .with_content(%r{pg2-path = /var/lib/postgresql/14/main})
        .without_content(%r{pg1-})
    end

    it 'does not export per-cluster singleton resources' do
      expect(exported_resources).not_to contain_exec('pgbackrest_stanza_create_psql.localhost-common')
      expect(exported_resources).not_to contain_cron('pgbackrest_incr_psql.localhost-common')
    end

    it 'writes local config with its own pg index and no pg-host' do
      is_expected.to contain_file('/etc/pgbackrest/conf.d/psql.conf')
        .with_content(%r{pg2-path = /var/lib/postgresql/14/main})
        .without_content(%r{pg2-host})
    end

    it 'still imports repository connection settings and exports pgpass entries' do
      expect(exported_resources).to contain_file_line('pgbackrest_pgpass_content-psql2')
    end
  end

  context 'standby replica with custom ssh port' do
    let(:params) do
      {
        hostname: 'psql2',
        cluster: 'psql',
        id: 2,
        ssh_port: 2222,
        version: '14',
      }
    end

    it 'exports member config with pg-host-port' do
      expect(exported_resources).to contain_file('/etc/pgbackrest/conf.d/psql-2.conf')
        .with_content(%r{pg2-host-port = 2222})
    end
  end

  context 'standalone instance with a b-suffixed hostname' do
    let(:facts) do
      os_facts.merge(networking: os_facts[:networking].merge('hostname' => 'psql01b'))
    end
    let(:params) do
      {
        hostname: 'psql01b',
        version: '14',
      }
    end

    it 'uses pg1 regardless of the hostname suffix' do
      is_expected.to contain_file('/etc/pgbackrest/conf.d/psql01b.conf')
        .with_content(%r{pg1-path})
        .without_content(%r{pg2-})
    end
  end

  context 'clustered instance with a b-suffixed hostname' do
    let(:facts) do
      os_facts.merge(networking: os_facts[:networking].merge('hostname' => 'psql01b'))
    end
    let(:params) do
      {
        hostname: 'psql01b',
        cluster: 'psql01',
        version: '14',
      }
    end

    it 'derives pg2 from the hostname suffix' do
      is_expected.to contain_file('/etc/pgbackrest/conf.d/psql01.conf')
        .with_content(%r{pg2-path})
    end
  end

  context 'primary role detected from pg_is_in_recovery fact' do
    let(:facts) { os_facts.merge('pgbackrest' => { 'in_recovery' => false }) }
    let(:params) do
      {
        backups: {
          common: {
            full: {},
          },
        },
        hostname: 'psql2',
        cluster: 'psql',
        id: 2,
        version: '14',
      }
    end

    it 'exports per-cluster singleton resources despite id != 1' do
      expect(exported_resources).to contain_exec('pgbackrest_stanza_create_psql.localhost-common')
      expect(exported_resources).to contain_cron('pgbackrest_full_psql.localhost-common')
    end
  end

  context 'standby role detected from pg_is_in_recovery fact' do
    let(:facts) { os_facts.merge('pgbackrest' => { 'in_recovery' => true }) }
    let(:params) do
      {
        backups: {
          common: {
            full: {},
          },
        },
        hostname: 'psql',
        cluster: 'psql',
        id: 1,
        version: '14',
      }
    end

    it 'does not export per-cluster singleton resources despite id == 1' do
      expect(exported_resources).not_to contain_exec('pgbackrest_stanza_create_psql.localhost-common')
      expect(exported_resources).not_to contain_cron('pgbackrest_full_psql.localhost-common')
    end

    it 'explicit primary parameter overrides the fact' do
      params[:primary] = true
      expect(exported_resources).to contain_exec('pgbackrest_stanza_create_psql.localhost-common')
    end
  end
end
