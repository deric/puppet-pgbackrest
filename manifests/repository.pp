# @summary PostgreSQL backups storage
#
# Configures pgBackRest backup server that can perform remote backups
#
# @param $backup_dir
#   Directory for storing backups
# @param user
#   Local user account used for running and storing backups in its home dir.
# @param group
#   Primary group of backup user
# @param purge_cron
#   Remove cron jobs not managed by Puppet
# @param manage_dirs
#   Whether directories should be managed by Puppet
#
# @example
#   include pgbackrest::repository
class pgbackrest::repository(
  Integer $id = 1,
  Stdlib::AbsolutePath            $backup_dir = $pgbackrest::backup_dir,
  Stdlib::AbsolutePath            $spool_dir = $pgbackrest::spool_dir,
  String                          $dir_mode = '0750',
  Optional[Stdlib::AbsolutePath]  $log_dir = $pgbackrest::log_dir,
  String                          $exported_ipaddress = "${::ipaddress}/32",
  String                          $user = $pgbackrest::backup_user,
  String                          $group = $pgbackrest::backup_group,
  Enum['present', 'absent']       $user_ensure = 'present',
  String                          $user_shell = '/bin/bash',
  String                          $host_key_type = $pgbackrest::host_key_type,
  Boolean                         $manage_ssh_keys = $pgbackrest::manage_ssh_keys,
  Boolean                         $manage_host_keys = $pgbackrest::manage_host_keys,
  Boolean                         $manage_pgpass = $pgbackrest::manage_pgpass,
  Boolean                         $manage_hba = $pgbackrest::manage_hba,
  Boolean                         $manage_cron = $pgbackrest::manage_cron,
  Boolean                         $manage_dirs = true,
  Boolean                         $manage_user = true,
  Boolean                         $manage_config = true,
  Boolean                         $purge_cron = false,
  Optional[Integer]               $uid = undef,
  Stdlib::AbsolutePath            $config_file = '/etc/pgbackrest.conf',
  String                          $host_group = $pgbackrest::host_group,
  Integer                         $hba_entry_order = 50,
  String                          $db_name = $pgbackrest::db_name,
  String                          $db_user = $pgbackrest::db_user,
  String                          $ssh_user = $pgbackrest::ssh_user,
  Hash                            $ssh_key_config = {},
  ) inherits pgbackrest {

  if $manage_user {
    group { $group:
      ensure => $user_ensure,
    }

    user { $user:
      ensure  => $user_ensure,
      uid     => $uid,
      gid     => $group, # a primary group
      home    => $backup_dir,
      shell   => $user_shell,
      require => Group[$group],
    }
  }

  if $manage_config {
    file { $config_file:
      ensure  => file,
      owner   => $user,
      group   => $group,
    }
  }

  if $manage_dirs {
    file { $backup_dir:
      ensure  => directory,
      owner   => $user,
      group   => $group,
      mode    => $dir_mode,
    }

    file { $spool_dir:
      ensure  => directory,
      owner   => $user,
      group   => $group,
      mode    => $dir_mode,
    }

    if $log_dir {
      file { $log_dir:
        ensure => directory,
        owner  => $user,
        group  => $group,
      }
    }
  }

  if $manage_ssh_keys {
    file { "${backup_dir}/.ssh":
      ensure  => directory,
      owner   => $user,
      group   => $group,
      mode    => '0700',
      require => File[$backup_dir],
    }

    file { "${backup_dir}/.ssh/known_hosts":
      ensure  => present,
      owner   => $user,
      group   => $group,
      mode    => '0600',
      require => File["${backup_dir}/.ssh"],
    }

    # Add public ssh keys from DB instances as authorized keys
    Ssh_authorized_key <<| tag == "pgbackrest-${host_group}-instance" |>>
  }

  if $manage_pgpass {
    # create an empty .pgpass file
    file { "${backup_dir}/.pgpass":
      ensure  => 'file',
      owner   => $user,
      group   => $group,
      mode    => '0600',
      require => File[$backup_dir],
    }

    # Fill the .pgpass file
    File_line <<| tag == "pgbackrest-${host_group}" |>>
  }

  Exec <<| tag == "pgbackrest_stanza_create-${host_group}" |>>

  if $manage_host_keys {
    # Import db instances host keys
    Sshkey <<| tag == "pgbackrest-${host_group}" |>>

    # Export catalog's host key
    @@sshkey { "pgbackrest-repository-${::fqdn}":
      ensure       => present,
      host_aliases => [$::hostname, $::fqdn, $::ipaddress],
      key          => $::sshecdsakey,
      type         => $host_key_type,
      target       => '/var/lib/postgresql/.ssh/known_hosts',
      tag          => "pgprobackup-catalog-${host_group}",
    }
  }

  if $manage_hba {
    # sufficient for full backup with enabled WAL archiving
    @@postgresql::server::pg_hba_rule { "pgbackrest ${::hostname} access":
      description => "pgbackrest ${::hostname} access",
      type        => 'host',
      database    => $pgbackrest::db_name,
      user        => $pgbackrest::db_user,
      address     => $exported_ipaddress,
      auth_method => 'md5',
      order       => $hba_entry_order,
      tag         => "pgbackrest-${host_group}",
    }

    # needed for streaming backups or full backup with --stream option
    @@postgresql::server::pg_hba_rule { "pgbackrest ${::hostname} replication":
      description => "pgbackrest ${::hostname} replication",
      type        => 'host',
      database    => 'replication',
      user        => $pgbackrest::db_user,
      address     => $exported_ipaddress,
      auth_method => 'md5',
      order       => $hba_entry_order,
      tag         => "pgbackrest-${host_group}",
    }
  }

  # Export (and add as authorized key) ssh key from pgbackup user
  # to all DB instances in host_group.
  if $manage_ssh_keys {
    # Load or generate ssh public and private key for given user
    $ssh_key = pgbackrest::ssh_keygen($ssh_user, $ssh_key_config)
    @@ssh_authorized_key { "pgbackrest-${::fqdn}":
      ensure => present,
      user   => 'postgres',
      type   => $ssh_key['type'],
      key    => $ssh_key['key'],
      tag    => "pgbackrest-repository-${host_group}",
    }
  }

  if $manage_cron {
    # Collect backup jobs to run
    Cron <<| tag == "pgbackrest-${host_group}" |>>

    if $purge_cron {
      # When enabled e.g. old entries will be removed
      resources { 'cron':
        purge => $purge_cron,
      }
    }
  }

}
