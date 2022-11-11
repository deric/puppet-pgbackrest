# @summary A PostgeSQL database instance to be backed up
#
# Manages configuration for postgresql database backup
#
# @param id
#   Unique identified
# @param cluster
#   Cluster name in case database has primary and some replicas.
# @param host_group
#   Default repository host group
# @param address
# @param port
# @param db_name
# @param db_user
# @param db_cluster
#   PostgreSQL cluster name, default: main
# @param db_password
# @param seed
#   Random password seed
# @param ssh_key_fact
# @param backup_dir
#   Directory where backups will be stored (might be located on remote server)
# @param backups
# @param ssh_user
#   user used for ssh connection to the DB instance
# @param ssh_port
#   ssh port used for connection to the DB instance from catalog server
#
# @example
#   include pgbackrest::stanza
class pgbackrest::stanza (
  String                            $id                   = $facts['networking']['hostname'],
  Optional[String]                  $cluster              = undef,
  String                            $host_group           = 'common',
  String                            $address              = $facts['networking']['fqdn'],
  Integer                           $port                 = 5432,
  String                            $db_name              = 'backup',
  String                            $db_user              = 'backup',
  String                            $db_cluster           = 'main',
  Variant[String,Sensitive[String]] $db_password          = '',
  Optional[String]                  $seed                 = undef,
  String                            $package_name         = 'pgbackrest',
  String                            $package_ensure       = 'present',
  Boolean                           $manage_dbuser        = true,
  Boolean                           $manage_ssh_keys      = false,
  Boolean                           $manage_host_keys     = true,
  Boolean                           $manage_pgpass        = true,
  Boolean                           $manage_hba           = true,
  Boolean                           $manage_cron          = true,
  String                            $ssh_user             = 'postgres',
  Integer                           $ssh_port             = 22,
  String                            $host_key_type        = 'ecdsa-sha2-nistp256',
  Hash                              $ssh_key_config       = {},
  Stdlib::AbsolutePath              $backup_dir           = '/var/lib/pgbackrest',
  Optional[Hash]                    $backups              = undef,
) {
  $_cluster = $cluster ? {
    undef   => $id,
    default => $cluster
  }

  class { 'pgbackrest::install':
    package_name => $package_name,
    ensure       => $package_ensure,
  }

  $_seed = $seed ? {
    undef   => fqdn_rand_string('64',''),
    default => $seed,
  }

  # Generate password if not defined
  $real_password = $db_password ? {
    ''      => fqdn_rand_string('64','',$_seed),
    default => $db_password =~ Sensitive ? {
      true  => $db_password.unwrap,
      false => $db_password
    },
  }

  if $manage_dbuser {
    postgresql::server::role { $db_user:
      login         => true,
      password_hash => postgresql_password($db_user, $real_password),
      superuser     => false,
      replication   => true,
    }

    postgresql::server::database { $db_name:
      owner   => $db_user,
      require => Postgresql::Server::Role[$db_user],
    }

    class { 'pgbackrest::grants':
      db_name => $db_name,
      db_user => $db_user,
      require => Postgresql::Server::Database[$db_name],
    }
  }

  # tag all target repositories
  if(!empty($backups)) {
    $tags = $backups.map|$group, $config| {
      "pgbackrest-${group}"
    }
  } else {
    $tags = ["pgbackrest-${host_group}"]
  }

  if $manage_host_keys {
    # Export own host key
    @@sshkey { "postgres-${address}":
      ensure       => present,
      host_aliases => [$facts['networking']['hostname'], $facts['networking']['fqdn'], $facts['networking']['ip'], $address],
      key          => $facts['ssh']['ecdsa']['key'],
      type         => $pgbackrest::stanza::host_key_type,
      target       => "${backup_dir}/.ssh/known_hosts",
      tag          => $tags,
    }
  }

  if $manage_ssh_keys {
    # Load or generate ssh public and private key for given user
    $ssh_key = pgbackrest::ssh_keygen($ssh_user, $ssh_key_config)
    @@ssh_authorized_key { "${ssh_user}-${facts['networking']['fqdn']}":
      ensure => present,
      user   => $ssh_user,
      type   => $ssh_key['type'],
      key    => $ssh_key['key'],
      tag    => $tags,
    }
  }

  if $manage_pgpass {
    # Export .pgpass content to pgprobackup catalog
    @@file_line { "pgbackrest_pgpass_content-${id}":
      path  => "${backup_dir}/.pgpass",
      line  => "${address}:${port}:${db_name}:${db_user}:${real_password}",
      match => "^${regexpescape($address)}:${port}:${db_name}:${db_user}",
      tag   => $tags,
    }

    @@file_line { "pgbackrest_pgpass_replication-${id}":
      path  => "${backup_dir}/.pgpass",
      line  => "${address}:${port}:replication:${db_user}:${real_password}",
      match => "^${regexpescape($address)}:${port}:replication:${db_user}",
      tag   => $tags,
    }
  }
}
