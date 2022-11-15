# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'

describe 'pgbackrest::stanza' do
  _, os_facts = on_supported_os.first

  let(:facts) { os_facts }

  let :pre_condition do
    'include postgresql::server'
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
        backups: {
          common: {
            FULL: {},
          },
        },
        id: 'psql',
        manage_ssh_keys: true,
        ssh_key_config: {
          'dir': '/tmp/.sshgen',
          'type': 'ed25519',
        },
      }
    end

    it {
      filename = '/tmp/.sshgen/id_ed25519.pub'
      content = 'ssh-ed25519 AVeryDummyKey comment@host'
      # mock ssh key
      allow(File).to receive(:exists?).with(filename).and_return(true)
      allow(File).to receive(:readlines).with(filename).and_return(StringIO.new(content))

      expect(exported_resources).to contain_ssh_authorized_key('postgres-psql.localhost')
        .with(
          user: 'postgres',
          type: 'ssh-ed25519',
          key: 'AVeryDummyKey',
          tag: ['pgbackrest-common'],
        )
    }
  end

  context 'with plain text password' do
    let(:params) do
      {
        backups: {
          common: {
            FULL: {},
          },
        },
        id: 'psql',
        port: 5433,
        db_name: 'pg_db',
        db_user:  'pg_user',
        db_password: 'TopSecret!',
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
end
