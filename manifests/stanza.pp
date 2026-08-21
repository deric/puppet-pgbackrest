# @summary A PostgreSQL database instance to be backed up
#
# Manages configuration for postgresql database backup. Exports resources
# (cluster config, ssh keys, pgpass entries, stanza-create command, cron jobs)
# that are collected by `pgbackrest::repository` on the backup server.
#
# @param hostname Unique identifier
# @param id Unique number of this instance within the cluster, used as the pg index
#   (`pg<id>-*` options) in the repository configuration. The primary should use 1,
#   each replica a distinct higher number. When unset it is derived from the
#   hostname suffix (see `pgbackrest::instance_id`), or defaults to 1 when no
#   `cluster` is set. NOTE: pgBackRest requires `pg1-*` options to exist —
#   repository-side commands (stanza-create, backup) fail without a member
#   with id 1, so a cluster whose only managed member would derive a higher
#   id must set `id: 1` explicitly.
# @param cluster Cluster name in case database has primary and some replicas.
#   All members of the cluster must use the same value (it becomes the stanza name).
# @param primary Whether this instance exports per-cluster singleton resources
#   (stanza-create command, backup cron jobs). Exactly one member of the cluster
#   must be primary. When unset, the role is detected at runtime from the
#   `pgbackrest.in_recovery` fact (`SELECT pg_is_in_recovery()`), so it follows
#   failovers; before PostgreSQL is up it falls back to `true` when `id` is 1.
# @param repo backup repository integer ID
# @param host_group Default repository host group
# @param version PostgreSQL major version, e.g. '16'
#   When unset, looked up from `postgresql::globals::version`
# @param address Address (fqdn) the repository server uses to reach this instance
# @param port PostgreSQL port
# @param db_name Database used for backup operations
# @param db_user DB role used for backup operations
# @param db_path
#   Typically postgres home directory
# @param db_cluster
#   PostgreSQL cluster name, default: main
# @param db_password
#   Password for `db_user`; randomly generated from `seed` when not given
# @param seed
#   Random password seed
# @param backup_dir
#   Directory where backups will be stored (might be located on remote server)
#  Default: /var/lib/pgbackrest
# @param spool_dir
#  Path where transient data is stored (should be on local filesystem)
#  Default: /var/spool/pgbackrest
# @param backups
#   Backup schedules keyed by repository host group, then by backup type
#   (`full`, `diff`, `incr`) with cron fields as values, e.g.
#   `{ 'common' => { 'incr' => { 'hour' => 3 }, 'full' => { 'weekday' => 0 } } }`.
#   No backups are scheduled when unset.
# @param config
#   Options written to /etc/pgbackrest/pgbackrest.conf, keyed by section,
#   e.g. `{ 'global' => { 'archive-async' => 'y', 'process-max' => 8 } }`
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
# @param user Unix account owning local pgBackRest config files (backup user on the repository server)
# @param group Primary unix group of `user`
# @param manage_dbuser whether db role should be managed
# @param manage_ssh_keys
#   Whether an ssh key pair should be generated for `ssh_user` and its public key
#   exported for the repository server
# @param manage_host_keys
#   Whether this host's ssh host key should be exported and the repository's host key imported
# @param manage_pgpass
#   Whether `.pgpass` entries with `db_user` credentials should be exported to the repository server
# @param manage_hba
#   Whether `pg_hba.conf` rules exported by the repository server should be collected
# @param manage_cron
#   Whether backup cron jobs should be exported to the repository server
# @param manage_user Whether unix user account should be managed
# @param manage_user_home Whether user's home directory should be created by puppet
# @param manage_archive_cmd Whether archive_command should be set on postgresql instance, changing archive_mode requires restart
# @param host_key_type ssh host key type, one of 'ecdsa', 'ed25519' or 'rsa'
# @param ssh_key_type Type of the generated ssh key pair, e.g. 'ed25519'
# @param log_dir Directory for pgBackRest log files
# @param log_level_file
#   Logging level for the file log, default: 'info'
#   Possible values 'off', 'error', 'warn', 'info', 'detail', 'debug', 'trace'
# @param compress_type File compression type, e.g. 'gz', 'lz4', 'zst' or 'bz2'
# @param compress_level File compression level (depends on `compress_type`)
# @param process_max Max processes to use for compress/transfer
# @param password_encryption Either md5 or scram-sha-256
# @param user_shell Shell of the backup user account
# @param user_ensure Whether the backup user account should be present or absent
# @param user_home Path to backup user home directory
# @param uid user account ID
# @param groups Unix groups to which the $user will belong
#
# @example
#   include pgbackrest::stanza
#
# @example Schedule daily incremental and weekly full backups (hiera)
#   pgbackrest::stanza::backups:
#     common:
#       incr:
#         hour: 3
#       full:
#         weekday: 0
class pgbackrest::stanza (
  String                             $hostname             = $facts['networking']['hostname'],
  Optional[Integer[1,256]]           $id                   = undef,
  Integer[1,256]                     $repo                 = 1,
  Optional[String]                   $cluster              = undef,
  String                             $host_group           = $pgbackrest::host_group,
  String                             $address              = $facts['networking']['fqdn'],
  Integer                            $port                 = 5432,
  String                             $db_name              = $pgbackrest::db_name,
  String                             $db_user              = $pgbackrest::db_user,
  String                             $db_cluster           = 'main',
  Optional[String]                   $version              = undef,
  Stdlib::AbsolutePath               $db_path              = '/var/lib/postgresql',
  Optional[Pgbackrest::Secret]       $db_password          = undef,
  Optional[String]                   $seed                 = undef,
  String                             $user                 = $pgbackrest::backup_user,
  String                             $group                = $pgbackrest::backup_group,
  Boolean                            $manage_dbuser        = false,
  Boolean                            $manage_ssh_keys      = $pgbackrest::manage_ssh_keys,
  Boolean                            $manage_host_keys     = $pgbackrest::manage_host_keys,
  Boolean                            $manage_pgpass        = $pgbackrest::manage_pgpass,
  Boolean                            $manage_hba           = $pgbackrest::manage_hba,
  Boolean                            $manage_cron          = $pgbackrest::manage_cron,
  Boolean                            $manage_user          = $pgbackrest::manage_user,
  Boolean                            $manage_archive_cmd   = true,
  Boolean                            $manage_user_home     = true,
  String                             $ssh_user             = $pgbackrest::ssh_user,
  Integer                            $ssh_port             = 22,
  String                             $host_key_type        = $pgbackrest::host_key_type,
  String                             $ssh_key_type         = 'ed25519',
  Stdlib::AbsolutePath               $backup_dir           = $pgbackrest::backup_dir,
  Stdlib::AbsolutePath               $spool_dir            = $pgbackrest::spool_dir,
  Stdlib::AbsolutePath               $log_dir              = $pgbackrest::log_dir,
  Postgresql::Pg_password_encryption $password_encryption  = $pgbackrest::password_encryption,
  Optional[Hash]                     $backups              = undef,
  Hash[String, Hash]                 $config               = {},
  Pgbackrest::LogLevel               $log_level_console    = 'warn',
  Pgbackrest::LogLevel               $log_level_file       = 'info',
  Pgbackrest::CompressType           $compress_type        = 'gz',
  Optional[Pgbackrest::CompressLevel] $compress_level       = undef,
  Optional[Integer[1,999]]           $process_max          = undef,
  Optional[Integer]                  $archive_timeout      = undef,
  Optional[Stdlib::AbsolutePath]     $binary               = undef,
  Boolean                            $redirect_console     = false,
  String                             $user_shell           = '/bin/bash',
  Enum['present', 'absent']          $user_ensure          = 'present',
  Optional[Stdlib::AbsolutePath]     $user_home            = undef,
  Optional[Integer]                  $uid                  = undef,
  Array[String]                      $groups               = [],
  Optional[Boolean]                  $primary              = undef,
) inherits pgbackrest {
  # pgBackRest requires pg1-* to be defined for repository-side commands
  # (stanza-create, backup), so a standalone instance must always be pg1;
  # the hostname suffix is only meaningful within a named cluster.
  $_id = $id ? {
    undef   => $cluster ? {
      undef   => 1,
      default => pgbackrest::instance_id($facts['networking']['hostname']),
    },
    default => $id,
  }

  if $primary !~ Undef {
    $_primary = $primary
  } elsif 'pgbackrest' in $facts and 'in_recovery' in $facts['pgbackrest'] {
    $_primary = !$facts['pgbackrest']['in_recovery']
  } else {
    # PostgreSQL not running yet (e.g. initial deployment)
    $_primary = $_id == 1
  }

  $_version = $version ? {
    undef   => lookup('postgresql::globals::version'),
    default => $version
  }

  $_cluster = $cluster ? {
    undef   => $hostname,
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

  $_home = $user_home ? {
    undef   => $user == 'postgres' ? {
      true  => '/var/lib/postgresql',
      false => "/home/${user}",
    },
    default => $user_home,
  }

  # home of the account used for the ssh connection (may differ from $user/$_home)
  $_ssh_home = $ssh_user == 'postgres' ? {
    true  => '/var/lib/postgresql',
    false => "/home/${ssh_user}",
  }

  if $manage_user {
    group { $group:
      ensure => $user_ensure,
    }

    user { $user:
      ensure     => $user_ensure,
      uid        => $uid,
      gid        => $group, # a primary group
      home       => $_home,
      managehome => $manage_user_home,
      shell      => $user_shell,
      require    => Group[$group],
    }

    if !empty($groups) {
      User<| title == $user |> {
        groups => $groups,
      }
    }
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
      version => $_version,
      require => Postgresql::Server::Database[$db_name],
    }

    # when connected via ssh the user needs to be able to login via socket/local connection
    postgresql::server::pg_hba_rule { "pgbackrest ${db_user} access":
      description => "pgbackrest ${db_user} access",
      type        => 'local',
      database    => $pgbackrest::db_name,
      user        => $pgbackrest::db_user,
      auth_method => $password_encryption,
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
    $_ssh_dir = "${_ssh_home}/.ssh"
    unless defined(File[$_ssh_dir]) {
      file { $_ssh_dir:
        ensure => directory,
        owner  => $ssh_user,
        mode   => '0700',
      }
    }

    $privkey_path = pgbackrest::ssh_key_path("${_ssh_home}/.ssh", $ssh_key_type, false)
    $pubkey_path = pgbackrest::ssh_key_path("${_ssh_home}/.ssh", $ssh_key_type, true)
    exec { "pgbackrest-generate-ssh-key_${ssh_user}":
      command => "su - ${ssh_user} -c \"ssh-keygen -t ${ssh_key_type} -q -N '' -f ${privkey_path}\"",
      path    => ['/usr/bin'],
      onlyif  => "test ! -f ${privkey_path}",
      require => File["${_ssh_home}/.ssh"],
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
        user   => $user,
        type   => $facts['pgbackrest'][$ssh_user]['type'],
        key    => $ssh_key,
        tag    => $tags,
      }
    }
  }

  if $manage_pgpass {
    # Export .pgpass content to pgprobackup catalog
    @@file_line { "pgbackrest_pgpass_content-${hostname}":
      path  => "${backup_dir}/.pgpass",
      line  => "${address}:${port}:${db_name}:${db_user}:${real_password}",
      match => "^${regexpescape($address)}:${port}:${db_name}:${db_user}",
      tag   => $tags,
    }

    @@file_line { "pgbackrest_pgpass_replication-${hostname}":
      path  => "${backup_dir}/.pgpass",
      line  => "${address}:${port}:replication:${db_user}:${real_password}",
      match => "^${regexpescape($address)}:${port}:replication:${db_user}",
      tag   => $tags,
    }
  }

  class { 'pgbackrest::config':
    config => $config,
  }

  $db_conf = {
    'log-level-console' => $log_level_console,
    "pg${_id}-path" => "${db_path}/${_version}/${db_cluster}",
    "pg${_id}-database" => $db_name,
    "pg${_id}-user" => $db_user,
  }

  # local config
  file { "${pgbackrest::config_subdir}/${_cluster}.conf":
    ensure  => file,
    owner   => $user,
    group   => $group,
    content => epp("${module_name}/cluster.epp", {
        'cluster' => $_cluster,
        'config'  => $db_conf,
    }),
    require => File[$pgbackrest::config_subdir],
  }

  # Remote config on backup server: one file per cluster member, all declaring
  # the same [cluster] section with disjoint pg<id>-* keys. pgBackRest merges
  # every file in conf.d, so primary and replicas end up in a single stanza.
  $remote_conf = {
    "pg${_id}-host"      => $address,
    "pg${_id}-host-user" => $ssh_user,
    "pg${_id}-path"      => "${db_path}/${_version}/${db_cluster}",
    "pg${_id}-port"      => String($port),
    "pg${_id}-database"  => $db_name,
    "pg${_id}-user"      => $db_user,
  }

  $_remote_conf = $ssh_port == 22 ? {
    true  => $remote_conf,
    false => $remote_conf + { "pg${_id}-host-port" => String($ssh_port) },
  }

  @@file { "${pgbackrest::config_subdir}/${_cluster}-${_id}.conf":
    ensure  => file,
    owner   => $user,
    group   => $group,
    mode    => '0640',
    content => epp("${module_name}/cluster.epp", {
        'cluster' => $_cluster,
        'config'  => $_remote_conf,
    }),
    tag     => $tags,
  }

  if $manage_archive_cmd {
    postgresql::server::config_entry { 'archive_mode':
      value => 'on', # restart required
    }

    postgresql::server::config_entry { 'archive_command':
      # command is executed by postgres user
      value => "pgbackrest --stanza=${_cluster} archive-push %p", # reload
    }
  }

  if !empty($backups) {
    $backups.each |String $host_group, Hash $config| {
      # stanza-create is per-cluster, exporting it from every member would
      # race for the stanza lock on the repository
      if $_primary {
        @@exec { "pgbackrest_stanza_create_${address}-${host_group}":
          command => "pgbackrest stanza-create --stanza=${_cluster}",
          path    => ['/usr/bin', '/bin'],
          cwd     => $backup_dir,
          # `pgbackrest info` takes no locks, so an already-created stanza is
          # skipped even while a backup or archive-push holds the stanza lock
          onlyif  => "pgbackrest info --stanza=${_cluster} | grep -q 'missing stanza'",
          tag     => "pgbackrest_stanza_create-${host_group}",
          user    => $user, # note: error output might not be captured
          require => [Package[$pgbackrest::package_name], Class['Pgbackrest::Config']],
        }
      }

      # Collect resources exported by pgbackrest::repository
      Postgresql::Server::Pg_hba_rule <<| tag == "pgbackrest-${host_group}" |>>

      # Import repository connection details (repo${repo}-host, repo${repo}-host-user,
      # repo${repo}-host-port) into this instance's pgbackrest.conf
      Ini_setting <<| tag == "pgbackrest-repository-${host_group}" |>> {
        require => Class['Pgbackrest::Config'],
      }

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

      # backups run per-stanza (pgBackRest picks the primary or a standby
      # itself), so only one member exports the cron jobs; the resource is
      # keyed by the cluster name so a failover replaces the same cron entry
      # on the repository instead of adding one per member
      if $manage_cron and $_primary {
        $config.each |$backup_type, $schedule| {
          # declare cron job, use defaults from stanza
          create_resources(pgbackrest::cron_backup, { "cron_backup-${host_group}-${_cluster}-${backup_type}" => $schedule }, {
              id                   => $_id,
              hostname             => $hostname,
              repo                 => $repo,
              cluster              => $_cluster,
              db_name              => $db_name,
              db_user              => $db_user,
              host_group           => $host_group,
              backup_dir           => $backup_dir,
              backup_type          => $backup_type,
              backup_user          => $user,
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
