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
        config_file: '/etc/pgbackrest.conf',
        user: 'pgbackup',
        group: 'pgbackup',
        log_dir: '/backup/log',
        spool_dir: '/backup/spool',
      }
    end

    it {
      is_expected.to contain_file('/etc/pgbackrest.conf')
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
          path: '/etc/pgbackrest.conf'
        },
      )
    }

    it {
      is_expected.to contain_ini_setting('global spool-path').with(
        {
          ensure: 'present', section: 'global',
          setting: 'spool-path', value: '/backup/spool',
          path: '/etc/pgbackrest.conf'
        },
      )
    }
  end
end
