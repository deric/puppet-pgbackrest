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
# @param repo
#   Set the repository for a command to operate on, default: 1
# @param version PostgreSQL major version, e.g. '16'
# @param address
# @param port
# @param db_name
# @param db_user
# @param db_path
#   Typically postgres home directory
# @param db_cluster
#   PostgreSQL cluster name, default: main
# @param db_password
# @param seed
#   Random password seed
# @param backup_dir
#   Directory where backups will be stored (might be located on remote server)
#  Default: /var/lib/pgbackrest
# @param spool_dir
#  Path where transient data is stored (should be on local filesystem)
#  Default: /var/spool/pgbackrest
# @param backups
# @param ssh_user
#   user used for ssh connection to the DB instance
# @param ssh_port
#   ssh port used for connection to the DB instance from catalog server
# @param log_level_console
#   Logging level, default: 'warn'
#   Possible values 'off', 'error', 'warn', 'info', 'detail', 'debug', 'trace'
# @param archive_timeout
#   Set maximum time, in seconds, to wait for each WAL segment to reach the pgBackRest archive repository
# @param binary
#   Full path to backup executable.
# @param redirect_console
#   Redirect console output to a log file (make sense especially with custom backup command)
#
# @example
#   include pgbackrest::stanza
class pgbackrest::stanza (
  String                            $id                   = $facts['networking']['hostname'],
  Optional[String]                  $cluster              = undef,
  String                            $host_group           = $pgbackrest::host_group,
  Integer[1,256]                    $repo                 = 1,
  String                            $address              = $facts['networking']['fqdn'],
  Integer                           $port                 = 5432,
  String                            $db_name              = $pgbackrest::db_name,
  String                            $db_user              = $pgbackrest::db_user,
  String                            $db_cluster           = 'main',
  String                            $version              = lookup('postgresql::globals::version'),
  Stdlib::AbsolutePath              $db_path              = '/var/lib/postgresql',
  Optional[Pgbackrest::Secret]      $db_password          = undef,
  Optional[String]                  $seed                 = undef,
  Boolean                           $manage_dbuser        = true,
  Boolean                           $manage_ssh_keys      = $pgbackrest::manage_ssh_keys,
  Boolean                           $manage_host_keys     = $pgbackrest::manage_host_keys,
  Boolean                           $manage_pgpass        = $pgbackrest::manage_pgpass,
  Boolean                           $manage_hba           = $pgbackrest::manage_hba,
  Boolean                           $manage_cron          = $pgbackrest::manage_cron,
  String                            $ssh_user             = 'postgres',
  Integer                           $ssh_port             = 22,
  String                            $host_key_type        = $pgbackrest::host_key_type,
  String                            $ssh_key_type         = 'ed25519',
  Stdlib::AbsolutePath              $backup_dir           = $pgbackrest::backup_dir,
  Stdlib::AbsolutePath              $spool_dir            = $pgbackrest::spool_dir,
  Stdlib::AbsolutePath              $log_dir              = $pgbackrest::log_dir,
  String                            $backup_user          = $pgbackrest::backup_user,
  Optional[Hash]                    $backups              = undef,
  Pgbackrest::LogLevel              $log_level_console    = 'warn',
  Pgbackrest::LogLevel              $log_level_file       = 'info',
  Pgbackrest::CompressType          $compress_type        = 'gz',
  Optional[Integer[0,9]]            $compress_level       = undef,
  Optional[Integer[1,999]]          $process_max          = undef,
  Optional[Integer]                 $archive_timeout      = undef,
  Optional[Stdlib::AbsolutePath]    $binary               = undef,
  Boolean                           $redirect_console     = false,
) inherits pgbackrest {
  $_cluster = $cluster ? {
    undef   => $id,
    default => $cluster
  }

  $_seed = $seed ? {
    undef   => stdlib::fqdn_rand_string(64),
    default => $seed,
  }

  # Generate password if not defined
  $real_password = $db_password ? {
    undef   => stdlib::fqdn_rand_string(64, undef, $_seed),
    default => $db_password =~ Sensitive ? {
      true  => $db_password.unwrap,
      false => $db_password
    },
  }

  if $manage_dbuser {
    postgresql::server::role { $db_user:
      # db            => $db_name, # first we need to create a role, then database
      login         => true,
      password_hash => postgresql::postgresql_password($db_user, $real_password),
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
      version => $version,
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
      key          => $facts['ssh'][$host_key_type]['key'],
      type         => $facts['ssh'][$host_key_type]['type'],
      target       => "${backup_dir}/.ssh/known_hosts",
      tag          => $tags,
    }
  }

  if $manage_ssh_keys {
    $privkey_path = pgbackrest::ssh_key_path("${db_path}/.ssh", $ssh_key_type, false)
    $pubkey_path = pgbackrest::ssh_key_path("${db_path}/.ssh", $ssh_key_type, true)
    exec { "pgbackrest-generate-ssh-key_${ssh_user}":
      command => "su - ${ssh_user} -c \"ssh-keygen -t ${ssh_key_type} -q -N '' -f ${privkey_path}\"",
      path    => ['/usr/bin'],
      onlyif  => "test ! -f ${privkey_path}",
    }

    file { '/var/cache/pgbackrest':
      ensure => directory,
      owner  => $ssh_user,
      group  => $ssh_user,
    }

    ini_setting { 'pgbackrest-stanza':
      ensure    => present,
      path      => '/var/cache/pgbackrest/exported_keys.ini',
      section   => 'stanza',
      setting   => $ssh_user,
      value     => $pubkey_path,
      show_diff => true,
      require   => File['/var/cache/pgbackrest'],
    }

    # Load ssh public key for given local user
    # NOTE: we can't access remote disk from a compile server
    # and exported resources doesn't support Deferred objects

    if 'pgbackrest' in $facts and $ssh_user in $facts['pgbackrest'] {
      $ssh_key = $facts['pgbackrest'][$ssh_user]['key']
      @@ssh_authorized_key { "${ssh_user}-${address}":
        ensure => present,
        user   => $backup_user,
        type   => $facts['pgbackrest'][$ssh_user]['type'],
        key    => $ssh_key,
        tag    => $tags,
      }
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

  if !empty($backups) {
    $backups.each |String $host_group, Hash $config| {
      @@exec { "pgbackrest_stanza_create_${address}-${host_group}":
        command => @("CMD"/L),
        pgbackrest stanza-create --stanza=${_cluster} --log-level-console=${log_level_console} \
        --pg1-host=${address} --pg1-path=${db_path}/${version}/${db_cluster} --pg1-port=${port} \
        --pg1-database=${db_name} --pg1-user=${db_user} --pg1-host-user=${ssh_user}
        | -CMD
        path    => ['/usr/bin'],
        cwd     => $backup_dir,
        #onlyif  => "test ! -d ${backup_dir}/backups/${_cluster}",
        tag     => "pgbackrest_stanza_create-${host_group}",
        user    => $backup_user, # note: error output might not be captured
        require => Package[$pgbackrest::package_name],
      }

      # Collect resources exported by pgbackrest::repository
      Postgresql::Server::Pg_hba_rule <<| tag == "pgbackrest-${host_group}" |>>

      if $manage_ssh_keys {
        # Import public key from backup server as authorized
        Ssh_authorized_key <<| tag == "pgbackrest-repository-${host_group}" |>> {
          require => Class['postgresql::server'],
        }
      }

      if $manage_host_keys {
        # Import backup server host key
        Sshkey <<| tag == "pgbackrest-repository-${host_group}" |>>
      }

      if $manage_cron {
        $config.each |$backup_type, $schedule| {
          # declare cron job, use defaults from stanza
          create_resources(pgbackrest::cron_backup, { "cron_backup-${host_group}-${address}-${backup_type}" => $schedule }, {
              id                   => $id,
              repo                 => $repo,
              cluster              => $_cluster,
              db_name              => $db_name,
              db_user              => $db_user,
              host_group           => $host_group,
              backup_dir           => $backup_dir,
              backup_type          => $backup_type,
              backup_user          => $backup_user,
              server_address       => $address,
              process_max          => $process_max,
              compress_type        => $compress_type,
              compress_level       => $compress_level,
              archive_timeout      => $archive_timeout,
              log_dir              => $log_dir,
              log_level_file       => $log_level_file,
              log_level_console    => $log_level_console,
              binary               => $binary,
              redirect_console     => $redirect_console,
          })
        }
      } # manage_cron
    } # host_group
  }
}
