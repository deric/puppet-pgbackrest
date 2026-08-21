# @api private
# @summary A cron job is exported from a database server, but could be executed elsewhere.
#
# Typically on a catalog (backup) server. The exported resource is keyed by the cluster (stanza) name, not the member
# address, so the whole cluster gets a single cron entry per backup type that
# follows the primary across failovers instead of accumulating one per member.
#
# @param id Numeric identifier of the DB instance within the stanza (used as `--pg<id>-user`)
# @param hostname Hostname of the database server the backup is exported from
# @param cluster Stanza (cluster) name passed as `--stanza`
# @param repo Repository integer ID, passed as `--repo`
# @param host_group The name of the backup repository (host group) collecting this cron entry
# @param backup_type Type of backup to run: `full`, `diff` or `incr`
# @param db_name Database name used for backup operations
# @param db_user DB role used for backup operations
# @param backup_user Unix account the cron job runs under on the repository host
# @param backup_dir Directory where backups are stored
# @param compress_type File compression type, passed as `--compress-type`
# @param redirect_console Whether to redirect the command's console output (stdout and stderr) to a file in `log_dir`
# @param log_dir Directory for pgBackRest log files, passed as `--log-path`
# @param log_level_file Log level for the file log, passed as `--log-level-file`
# @param log_level_console Log level for console output, passed as `--log-level-console`
# @param process_max Max processes to use for compress/transfer, passed as `--process-max`
# @param hour Cron hour(s) the backup runs at
# @param minute Cron minute(s) the backup runs at
# @param month Cron month(s) the backup runs in
# @param weekday Cron day(s) of the week the backup runs on
# @param compress_level File compression level, passed as `--compress-level`
# @param archive_timeout WAL segment archive timeout in seconds, passed as `--archive-timeout`
# @param monthday Cron day(s) of the month the backup runs on
# @param binary Path to the pgbackrest executable (defaults to `/usr/bin/pgbackrest`)
# @param log_console File name (within `log_dir`) console output is redirected to when `redirect_console` is enabled, defaults to `<cluster>.log`
define pgbackrest::cron_backup (
  Integer[1,256]                  $id,
  String                          $hostname,
  String                          $cluster,
  Integer[1,256]                  $repo,
  String                          $host_group,
  Pgbackrest::BackupType          $backup_type,
  String                          $db_name,
  String                          $db_user,
  String                          $backup_user,
  Stdlib::AbsolutePath            $backup_dir,
  Pgbackrest::CompressType        $compress_type = 'gz',
  Boolean                         $redirect_console = false,
  Stdlib::AbsolutePath            $log_dir = '/var/log/pgbackrest',
  Pgbackrest::LogLevel            $log_level_file = 'info',
  Pgbackrest::LogLevel            $log_level_console = 'warn',
  Optional[Integer[1,999]]        $process_max = undef,
  Pgbackrest::Hour                $hour = 4,
  Pgbackrest::Minute              $minute = 0,
  Pgbackrest::Month               $month = '*',
  Pgbackrest::Weekday             $weekday = '*',
  Optional[Pgbackrest::CompressLevel] $compress_level = undef,
  Optional[Integer]               $archive_timeout = undef,
  Optional[Pgbackrest::Monthday]  $monthday = undef,
  Optional[String]                $binary = undef,
  Optional[String]                $log_console = undef,
) {
  @@cron { "pgbackrest_${backup_type}_${cluster}-${host_group}":
    command  => epp('pgbackrest/cron_backup.epp', {
        id                => $id,
        hostname          => $hostname,
        repo              => $repo,
        cluster           => $cluster,
        db_name           => $db_name,
        db_user           => $db_user,
        host_group        => $host_group,
        backup_dir        => $backup_dir,
        backup_type       => $backup_type,
        backup_user       => $backup_user,
        process_max       => $process_max,
        compress_type     => $compress_type,
        compress_level    => $compress_level,
        archive_timeout   => $archive_timeout,
        log_dir           => $log_dir,
        log_level_file    => $log_level_file,
        log_level_console => $log_level_console,
        binary            => $binary,
        redirect_console  => $redirect_console,
        log_console       => $log_console,
    }),
    user     => $backup_user,
    weekday  => $weekday,
    hour     => $hour,
    minute   => $minute,
    month    => $month,
    monthday => $monthday,
    tag      => "pgbackrest-${host_group}",
  }
}
