# frozen_string_literal: true
require 'facter'
# https://github.com/puppetlabs/puppet-specifications/blob/master/language/func-api.md#the-4x-api
#
#  username
#  ssh_dir
#  config = {
#    type = rsa | dsa | ecdsa | ed25519
#  }
#
Puppet::Functions.create_function(:"pgbackrest::ssh_keygen") do
  dispatch :ssh_keygen do
    param 'String', :username
    param 'String', :ssh_dir
    param 'Hash', :config
    return_type 'Hash'
  end

  def pubkey_file(dir, config)
    pubkey = case ssh_key_type(config)
             when 'dsa'
               'id_dsa.pub'
             when 'rsa'
               'id_rsa.pub'
             when 'ecdsa'
               'id_ecdsa.pub'
             when 'ecdsa-sk'
               'id_ecdsa_sk.pub'
             when 'ed25519'
               'id_ed25519.pub'
             when 'ed25519-sk'
               'id_ed25519_sk.pub'
             end

    "#{dir}/#{pubkey}"
  end

  def fetch_key(path)
    lines = File.readlines(path)
    content = if lines.respond_to? :string
                lines.string
              elsif lines.respond_to? :join
                lines.join('')
              else
                lines
              end
    parse_ssh_key(content)
  end

  def parse_ssh_key(str)
    matched = str.match(%r{((sk-ecdsa-|ssh-|ecdsa-)[^\s]+)\s+([^\s]+)\s+(.*)$})
    raise ArgumentError, "Wrong Keyline format: #{str}" unless matched && matched.length == 5
    key = {
      'type' => matched[1],
      'key' => matched[3],
    }
    options = str[0, str.index(matched[0])].rstrip
    comment = matched[4]
    key['options'] = options unless options.empty?
    key['comment'] = comment unless comment.empty?

    key
  end

  def ssh_key_type(config)
    if config.key? 'type'
      return config['type']
    end
    'ed25519'
  end

  # Generate ssh key
  def generate_key(user, path, config)
    private_path = path.delete_suffix('.pub')
    return if File.exist?(private_path)
    Facter::Util::Resolution.exec("su - #{user} -c \"ssh-keygen -t #{ssh_key_type(config)} -q -N '' -f #{private_path}\"")
  end

  def fetch_or_generate(username, path, config)
    unless File.exist?(path)
      generate_key(username, path, config)
    end
    fetch_key(path)
  end

  def ssh_keygen(username, ssh_dir, config = {})
    path = pubkey_file(ssh_dir, config)
    fetch_or_generate(username, path, config)
  end
end
