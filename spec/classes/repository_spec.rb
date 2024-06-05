# frozen_string_literal: true

require 'spec_helper'

describe 'pgbackrest::repository' do
  _, os_facts = on_supported_os.first

  let(:facts) { os_facts }

  it { is_expected.to compile }

  it {
    is_expected.to contain_package('pgbackrest').with_ensure(%r{present|installed})
  }

  it { is_expected.to contain_class('pgbackrest::install') }

  it {
    is_expected.to contain_file('/var/lib/pgbackrest')
      .with(ensure: 'directory',
            owner: 'backup',
            group: 'backup',
            mode: '0750')
  }

  it { is_expected.to contain_user('backup') }
  it { is_expected.to contain_group('backup') }

  context 'with manage_user: true' do
    let(:params) do
      {
        manage_user: true,
        user: 'pgbackup',
        group: 'pgbackup',
      }
    end

    it { is_expected.to contain_user('pgbackup') }
    it { is_expected.to contain_group('pgbackup') }
  end

  context 'with log directory' do
    let(:params) do
      {
        log_dir: '/var/log/pgbackrest',
        user: 'pgbackup',
        group: 'pgbackup',
        manage_dirs: true,
      }
    end

    it {
      is_expected.to contain_file('/var/log/pgbackrest')
        .with(ensure: 'directory',
              owner: 'pgbackup',
              group: 'pgbackup')
    }
  end

  context 'with manage_config' do
    let(:params) do
      {
        manage_config: true,
        config_dir: '/etc/pgbackrest',
        config_file: 'pgbackrest.conf',
        user: 'pgbackup',
        group: 'pgbackup',
        log_dir: '/backup/log',
        spool_dir: '/backup/spool',
      }
    end

    it {
      is_expected.to contain_file('/etc/pgbackrest.conf')
        .with(ensure: 'absent')
    }

    it {
      is_expected.to contain_file('/etc/pgbackrest/pgbackrest.conf')
        .with(ensure: 'file',
              owner: 'pgbackup',
              group: 'pgbackup')
    }

    it { is_expected.to contain_class('pgbackrest::config') }

    it {
      is_expected.to contain_file('/backup/log')
        .with(ensure: 'directory',
            owner: 'pgbackup',
            group: 'pgbackup')
    }

    it {
      is_expected.to contain_file('/backup/spool')
        .with(ensure: 'directory',
            owner: 'pgbackup',
            group: 'pgbackup',
            mode: '0750')
    }

    it {
      is_expected.to contain_ini_setting('global log-path').with(
        {
          ensure: 'present', section: 'global',
          setting: 'log-path', value: '/backup/log',
          path: '/etc/pgbackrest/pgbackrest.conf'
        },
      )
    }

    it {
      is_expected.to contain_ini_setting('global spool-path').with(
        {
          ensure: 'present', section: 'global',
          setting: 'spool-path', value: '/backup/spool',
          path: '/etc/pgbackrest/pgbackrest.conf'
        },
      )
    }
  end

  context 'with manage_ssh_keys' do
    let(:params) do
      {
        manage_ssh_keys: true,
        manage_host_keys: true,
        user: 'pgbackup',
        group: 'pgbackup',
        backup_dir: '/var/lib/pgbackrest',
        ssh_key_type: 'ed25519',
      }
    end

    it {
      is_expected.to contain_file('/var/lib/pgbackrest/.ssh')
        .with(ensure: 'directory',
            owner: 'pgbackup',
            group: 'pgbackup',
            mode: '0700')
    }

    it {
      is_expected.to contain_file('/var/lib/pgbackrest/.ssh/known_hosts')
        .with(ensure: 'present',
            owner: 'pgbackup',
            group: 'pgbackup',
            mode: '0600')
    }

    it 'generates ssh key pair, if missing' do
      is_expected.to contain_exec('pgbackrest-generate-ssh-key_pgbackup').with(
        command: 'su - pgbackup -c "ssh-keygen -t ed25519 -q -N \'\' -f /var/lib/pgbackrest/.ssh/id_ed25519"',
      )
    end

    it 'exports public ssh key' do
      expect(exported_resources).to contain_ssh_authorized_key('pgbackrest-psql.localhost')
        .with(
          user: 'postgres',
          type: 'ssh-ed25519',
          key: 'AAAAC3NzaC1lZDI1NTE5AAAAIN1UTKrM47QYBXJg0cIgrausN4o93I17AIj4K3i+5yS4',
        )
    end

    it 'exports ssh host key' do
      expect(exported_resources).to contain_sshkey('pgbackrest-repository-psql.localhost').with(
        ensure: 'present',
        target: '/var/lib/postgresql/.ssh/known_hosts',
        key: 'AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBK0I9tmr+wzrGKYmc5aaI07KpRfxCM+eDjtFfguCD7hKeD3LOD5IO6irhYtjABBfZCJmTCs0U68Bc8LkHCAWvYw=',
        tag: ['pgbackrest-repository-common'],
      )
    end

    it {
      is_expected.to contain_file('/var/cache/pgbackrest')
        .with(ensure: 'directory',
            owner: 'pgbackup',
            group: 'pgbackup')
    }

    it {
      is_expected.to contain_ini_setting('pgbackrest-repository').with(
        {
          ensure: 'present',
          setting: 'pgbackup', value: '/var/lib/pgbackrest/.ssh/id_ed25519.pub',
          path: '/var/cache/pgbackrest/exported_keys.ini'
        },
      )
    }
  end
end
