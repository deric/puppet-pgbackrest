# frozen_string_literal: true

require 'etc'
# https://github.com/puppetlabs/puppet-specifications/blob/master/language/func-api.md#the-4x-api
#
#  username
#  config = {
#    type = rsa | dsa | ecdsa | ed25519
#    dir = ~/.ssh
#  }
#
Puppet::Functions.create_function(:"pgbackrest::ssh_keygen") do
  dispatch :ssh_keygen do
    param 'String', :username
    param 'Hash', :config
    return_type 'Hash'
  end

  def pubkey_file(entry_dir, config)
    dir = if config.key? 'dir'
            config['dir']
          else
            entry_dir
          end
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
    parse_ssh_key(File.readlines(path).string)
  end

  def parse_ssh_key(str)
    matched = str.match(%r{((sk-ecdsa-|ssh-|ecdsa-)[^\s]+)\s+([^\s]+)\s+(.*)$})
    raise ArgumentError, 'Wrong Keyline format!' unless matched && matched.length == 5
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
    puts("su - #{user} -c \"ssh-keygen -t #{ssh_key_type(config)} -P '' -f #{path}\"")
  end

  def ssh_keygen(username, config)
    Etc.passwd do |entry|
      if entry.name == username
        path = pubkey_file(entry.dir, config)

        unless File.exist?(path)
          generate_key(entry.name, path, config)
        end
        return fetch_key(path)
      end
    end
    {}
  end
end
