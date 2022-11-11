# frozen_string_literal: true

require 'spec_helper'

describe 'pgbackrest::ssh_keygen' do
  # expect(StringIO.new(content).read).to eq(content)
  it 'fetches ssh public key from disk' do
    filename = '/tmp/.sshgen/id_ed25519.pub'
    content = 'ssh-ed25519 AVeryDummyKey comment@host'
    # mock ssh key
    allow(File).to receive(:exist?).with(filename).and_return(true)
    allow(File).to receive(:readlines).with(filename).and_return(StringIO.new(content))

    is_expected.to run.with_params(ENV['USER'], { 'dir' => '/tmp/.sshgen' })\
                      .and_return(
        { 'type' => 'ssh-ed25519', 'key' => 'AVeryDummyKey', 'comment' => 'comment@host' },
      )
  end

  it { is_expected.to run.with_params(nil).and_raise_error(StandardError) }
end
