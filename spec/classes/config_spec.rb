# frozen_string_literal: true

require 'spec_helper'

describe 'pgbackrest::config' do
  _, os_facts = on_supported_os.first

  let(:facts) { os_facts }

  it { is_expected.to compile }

  it 'purges unmanaged files from conf.d by default' do
    is_expected.to contain_file('/etc/pgbackrest/conf.d').with(
      ensure: 'directory',
      purge: true,
      recurse: true,
    )
  end

  context 'with purge_config_dir disabled' do
    let(:params) { { purge_config_dir: false } }

    it 'does not purge conf.d' do
      is_expected.to contain_file('/etc/pgbackrest/conf.d').with(
        ensure: 'directory',
        purge: false,
        recurse: false,
      )
    end
  end
end
