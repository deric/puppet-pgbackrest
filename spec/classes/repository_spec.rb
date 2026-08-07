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
            owner: 'pgbackup',
            group: 'pgbackup',
            mode: '0750')
  }

  it { is_expected.to contain_user('pgbackup') }
  it { is_expected.to contain_group('pgbackup') }

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
        config: {
          'global': {
            'repo1-path': '/backup/pgbackrest',
            'repo1-retention-full': 1,
          },
          'global:archive-push': {
            'compress-level': 3,
          },
        }
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

    it {
      is_expected.to contain_file('/etc/pgbackrest/conf.d')
        .with(ensure: 'directory',
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

    it {
      is_expected.to contain_ini_setting('global repo1-path').with(
        {
          ensure: 'present', section: 'global',
          setting: 'repo1-path', value: '/backup/pgbackrest',
          path: '/etc/pgbackrest/pgbackrest.conf'
        },
      )
    }

    it {
      is_expected.to contain_ini_setting('global repo1-retention-full').with(
        {
          ensure: 'present', section: 'global',
          setting: 'repo1-retention-full', value: '1',
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
        .with(ensure: 'file',
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
        key: 'AAAAC3NzaC1lZDI1NTE5AAAAIDeht9izXWL1PlUn5YFgLqBnKiUld/Kd+YSefOCqqsnQ',
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

  context 'exports repository connection details' do
    let(:params) do
      {
        user: 'pgbackup',
        host_group: 'common',
      }
    end

    it 'exports repo1-host' do
      expect(exported_resources).to contain_ini_setting('repo1-host-psql.localhost').with(
        ensure: 'present',
        path: '/etc/pgbackrest/pgbackrest.conf',
        section: 'global',
        setting: 'repo1-host',
        value: 'psql.localhost',
        tag: ['pgbackrest-repository-common'],
      )
    end

    it 'exports repo1-host-user' do
      expect(exported_resources).to contain_ini_setting('repo1-host-user-psql.localhost').with(
        ensure: 'present',
        path: '/etc/pgbackrest/pgbackrest.conf',
        section: 'global',
        setting: 'repo1-host-user',
        value: 'pgbackup',
        tag: ['pgbackrest-repository-common'],
      )
    end

    it 'exports repo1-host-port' do
      expect(exported_resources).to contain_ini_setting('repo1-host-port-psql.localhost').with(
        ensure: 'present',
        path: '/etc/pgbackrest/pgbackrest.conf',
        section: 'global',
        setting: 'repo1-host-port',
        value: 22,
        tag: ['pgbackrest-repository-common'],
      )
    end

    context 'with a non-default repo id and ssh_port' do
      let(:params) do
        {
          user: 'pgbackup',
          host_group: 'offsite',
          repo: 2,
          ssh_port: 2222,
        }
      end

      it 'exports repo2-host settings tagged for the matching host_group' do
        expect(exported_resources).to contain_ini_setting('repo2-host-psql.localhost').with(
          setting: 'repo2-host',
          value: 'psql.localhost',
          tag: ['pgbackrest-repository-offsite'],
        )

        expect(exported_resources).to contain_ini_setting('repo2-host-user-psql.localhost').with(
          setting: 'repo2-host-user',
          value: 'pgbackup',
          tag: ['pgbackrest-repository-offsite'],
        )

        expect(exported_resources).to contain_ini_setting('repo2-host-port-psql.localhost').with(
          setting: 'repo2-host-port',
          value: 2222,
          tag: ['pgbackrest-repository-offsite'],
        )
      end
    end
  end
end
