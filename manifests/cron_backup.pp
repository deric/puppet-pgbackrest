# @api private
# A cron job is exported from a database server, but could be executed elsewhere.
# Typically on a catalog (backup) server.
define pgbackrest::cron_backup (
  String                          $id,
  String                          $cluster,
  Integer[1,256]                  $repo,
  String                          $host_group,
  Pgbackrest::BackupType          $backup_type,
  String                          $server_address,
  String                          $db_name,
  String                          $db_user,
  String                          $backup_user,
  Stdlib::AbsolutePath            $backup_dir,
  Pgbackrest::CompressType        $compress_type = 'gz',
  Boolean                         $redirect_console = false,
  Stdlib::AbsolutePath            $log_dir = '/var/log/pgbackrest',
  Pgbackrest::LogLevel            $log_level_file = 'info',
  Pgbackrest::LogLevel            $log_level_console = 'warn',
  Integer[1,999]                  $process_max = 1,
  Pgbackrest::Hour                $hour = 4,
  Pgbackrest::Minute              $minute = 0,
  Pgbackrest::Month               $month = '*',
  Pgbackrest::Weekday             $weekday = '*',
  Optional[Integer[0,9]]          $compress_level = undef,
  Optional[Integer]               $archive_timeout = undef,
  Optional[Pgbackrest::Monthday]  $monthday = undef,
  Optional[String]                $binary = undef,
  Optional[String]                $log_console = undef,
) {
  @@cron { "pgbackrest_${backup_type}_${server_address}-${host_group}":
    command  => epp('pgbackrest/cron_backup.epp', {
        id                => $id,
        repo              => $repo,
        cluster           => $cluster,
        db_name           => $db_name,
        db_user           => $db_user,
        host_group        => $host_group,
        backup_dir        => $backup_dir,
        backup_type       => $backup_type,
        backup_user       => $backup_user,
        server_address    => $server_address,
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
