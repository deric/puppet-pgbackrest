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


  context 'with manage_user: true' do
    let(:params) do
      {
        manage_user: true,
      }
    end

    it { is_expected.to contain_user('pgbackup') }
    it { is_expected.to contain_group('pgbackup') }
  end


  context 'with log directory' do
    let(:params) do
      {
        log_dir: '/var/log/pgbackrest',
      }
    end

    it {
      is_expected.to contain_file('/var/log/pgbackrest')
        .with(ensure: 'directory',
              owner: 'pgbackup',
              group: 'pgbackup')
    }
  end
end
