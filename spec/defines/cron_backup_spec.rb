# frozen_string_literal: true

require 'spec_helper'

describe 'pgbackrest::cron_backup' do
  _, os_facts = on_supported_os.first
  let(:title) { 'psql' }
  let(:facts) { os_facts }
  let(:params) do
    {
      hostname: 'psql01a',
      id: 1,
      repo: 1,
      cluster: 'psql01',
      host_group: 'common',
      backup_type: 'incr',
      db_name: 'backup',
      db_user: 'pgbackrest',
      backup_user: 'pgbackup',
      backup_dir: '/var/lib/pgbackrest',
    }
  end

  it { is_expected.to compile }

  it {
    expect(exported_resources).to contain_cron('pgbackrest_incr_psql01-common')
      .with(
        user: 'pgbackup',
        weekday: '*',
        hour: '4',
        minute: '0',
      )
  }

  context 'with zst compression and negative compress_level' do
    let(:params) do
      super().merge(compress_type: 'zst', compress_level: -7)
    end

    it { is_expected.to compile }

    it {
      expect(exported_resources).to contain_cron('pgbackrest_incr_psql01-common')
        .with(command: %r{--compress-type=zst --compress-level=-7})
    }
  end

  context 'with maximum zst compress_level' do
    let(:params) do
      super().merge(compress_type: 'zst', compress_level: 22)
    end

    it { is_expected.to compile }

    it {
      expect(exported_resources).to contain_cron('pgbackrest_incr_psql01-common')
        .with(command: %r{--compress-type=zst --compress-level=22})
    }
  end

  context 'with compress_level below allowed range' do
    let(:params) do
      super().merge(compress_type: 'zst', compress_level: -8)
    end

    it { is_expected.to compile.and_raise_error(%r{compress_level}) }
  end

  context 'with compress_level above allowed range' do
    let(:params) do
      super().merge(compress_type: 'zst', compress_level: 23)
    end

    it { is_expected.to compile.and_raise_error(%r{compress_level}) }
  end
end
