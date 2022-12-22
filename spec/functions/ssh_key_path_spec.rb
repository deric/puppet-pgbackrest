# frozen_string_literal: true

require 'spec_helper'

describe 'pgbackrest::ssh_key_path' do
  it { is_expected.to run.with_params(
      '/home/user/.ssh', 'rsa', true
    ).and_return('/home/user/.ssh/id_rsa.pub') }

  it { is_expected.to run.with_params(
      '/home/user/.ssh', 'ed25519', false
    ).and_return('/home/user/.ssh/id_ed25519') }

  it { is_expected.to run.with_params(nil).and_raise_error(StandardError) }
end
