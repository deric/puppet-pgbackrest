# @summary A PostgeSQL database instance to be backed up
#
# Manages configuration for postgresql database backup
#
# @param id
#   Unique identified
# @param cluster
#   Cluster name in case database has primary and some replicas.
# @param address
# @param port
# @param db_name
# @param db_user
# @param db_cluster
#    PostgreSQL cluster name, default: main
# @param db_password
# @param seed
#    Random password seed

#
# @example
#   include pgbackrest::stanza
class pgbackrest::stanza(
  String                            $id                   = $facts['hostname'],
  Optional[String]                  $cluster              = undef,
  String                            $address              = $facts['fqdn'],
  Integer                           $port                 = 5432,
  String                            $db_name              = 'backup',
  String                            $db_user              = 'backup',
  String                            $db_cluster           = 'main',
  Variant[String,Sensitive[String]] $db_password          = '',
  Optional[String]                  $seed                 = undef,
  String                            $package_name         = 'pgbackrest',
  String                            $package_ensure       = 'present',
  Boolean                           $manage_dbuser        = true,
  Boolean                           $manage_ssh_keys      = true,
  Boolean                           $manage_host_keys     = true,
  Boolean                           $manage_pgpass        = true,
  Boolean                           $manage_hba           = true,
  Boolean                           $manage_cron          = true,
  ) {

  $_cluster = $cluster ? {
    undef   => $id,
    default => $cluster
  }

  class {'pgbackrest::install':
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

    class {'pgbackrest::grants':
      db_name => $db_name,
      db_user => $db_user,
      require => Postgresql::Server::Database[$db_name],
    }
  }


}
