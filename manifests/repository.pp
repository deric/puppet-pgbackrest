# @summary PostgreSQL backups storage
#
# Configures pgBackRest backup server that can perform remote backups
#
# @param fqdn
# @param backup_dir
#   Directory for storing backups
# @param spool_dir
# @param dir_mode
# @param log_dir
# @param exported_ipaddress
# @param user
#   Local user account used for running and storing backups in its home dir.
# @param group
#   Primary group of backup user
# @param user_ensure
# @param user_shell Backup user shell
# @param host_key_type
# @param purge_cron
#   Remove cron jobs not managed by Puppet
# @param manage_dirs
#   Whether directories should be managed by Puppet
#
# @example
#   include pgbackrest::repository
class pgbackrest::repository (
  String                          $fqdn = $facts['networking']['fqdn'],
  Stdlib::AbsolutePath            $backup_dir = $pgbackrest::backup_dir,
  Stdlib::AbsolutePath            $spool_dir = $pgbackrest::spool_dir,
  String                          $dir_mode = '0750',
  Stdlib::AbsolutePath            $log_dir = $pgbackrest::log_dir,
  String                          $exported_ipaddress = "${facts['networking']['ip']}/32",
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
  Stdlib::AbsolutePath            $config_dir = $pgbackrest::config_dir,
  String                          $config_file = 'pgbackrest.conf',
  String                          $host_group = $pgbackrest::host_group,
  Integer                         $hba_entry_order = 50,
  String                          $db_name = $pgbackrest::db_name,
  String                          $db_user = $pgbackrest::db_user,
  String                          $ssh_user = $pgbackrest::ssh_user,
  String                          $ssh_key_type = 'ed25519',
  Hash                            $config = {},
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
    $_config = deep_merge($config, {
        'global' => {
          'log-path' => $log_dir,
          'spool-path' => $spool_dir,
        }
    })

    class { 'pgbackrest::config':
      config_dir  => $config_dir,
      config_file => $config_file,
      user        => $user,
      group       => $group,
      config      => $_config,
    }
  }

  if $manage_dirs {
    file { $backup_dir:
      ensure => directory,
      owner  => $user,
      group  => $group,
      mode   => $dir_mode,
    }

    file { $spool_dir:
      ensure => directory,
      owner  => $user,
      group  => $group,
      mode   => $dir_mode,
    }

    file { $log_dir:
      ensure => directory,
      owner  => $user,
      group  => $group,
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
      ensure  => file,
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
    @@sshkey { "pgbackrest-repository-${fqdn}":
      ensure       => present,
      host_aliases => [$facts['networking']['hostname'], $facts['networking']['fqdn'], $facts['networking']['ip']],
      key          => $facts['ssh'][$host_key_type]['key'],
      type         => $facts['ssh'][$host_key_type]['type'],
      target       => '/var/lib/postgresql/.ssh/known_hosts',
      tag          => "pgbackrest-repository-${host_group}",
    }
  }

  if $manage_hba {
    $hostname = $facts['networking']['hostname']
    # sufficient for full backup with enabled WAL archiving
    @@postgresql::server::pg_hba_rule { "pgbackrest ${hostname} access":
      description => "pgbackrest ${hostname} access",
      type        => 'host',
      database    => $pgbackrest::db_name,
      user        => $pgbackrest::db_user,
      address     => $exported_ipaddress,
      auth_method => 'md5',
      order       => $hba_entry_order,
      tag         => "pgbackrest-${host_group}",
    }

    # needed for streaming backups or full backup with --stream option
    @@postgresql::server::pg_hba_rule { "pgbackrest ${hostname} replication":
      description => "pgbackrest ${hostname} replication",
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
    $privkey_path = pgbackrest::ssh_key_path("${backup_dir}/.ssh", $ssh_key_type, false)
    $pubkey_path = pgbackrest::ssh_key_path("${backup_dir}/.ssh", $ssh_key_type, true)
    exec { "pgbackrest-generate-ssh-key_${user}":
      command => "su - ${user} -c \"ssh-keygen -t ${ssh_key_type} -q -N '' -f ${privkey_path}\"",
      path    => ['/usr/bin'],
      onlyif  => "test ! -f ${privkey_path}",
    }

    file { '/var/cache/pgbackrest':
      ensure => directory,
      owner  => $user,
      group  => $group,
    }

    ini_setting { 'pgbackrest-repository':
      ensure    => present,
      path      => '/var/cache/pgbackrest/exported_keys.ini',
      section   => 'repository',
      setting   => $user,
      value     => $pubkey_path,
      show_diff => true,
      require   => File['/var/cache/pgbackrest'],
    }

    # Load ssh public key for given local user
    # NOTE: we can't access remote disk from a compile server
    # and exported resources doesn't support Deferred objects
    if 'pgbackrest' in $facts and $user in $facts['pgbackrest'] {
      $ssh_key = $facts['pgbackrest'][$user]['key']
      @@ssh_authorized_key { "pgbackrest-${fqdn}":
        ensure => present,
        user   => $ssh_user,
        type   => $facts['pgbackrest'][$user]['type'],
        key    => $ssh_key,
        tag    => "pgbackrest-repository-${host_group}",
      }
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
