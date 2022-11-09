# @summary PostgreSQL backups storage
#
# Configures pgBackRest backup server that can perform remote backups
#
# @param $backup_dir
#   Directory for storing backups
# @param $user
#   Local user account used for running and storing backups in its home dir.
# @param $group
#   Primary group of backup user

#
# @example
#   include pgbackrest::repository
class pgbackrest::repository(
  Integer $id = 1,
  Stdlib::AbsolutePath              $backup_dir           = '/var/lib/pgbackrest',
  String                            $user                 = 'postgres',
  String                            $group                = 'postgres',
  String                            $dir_mode = '0750',

  ) {

  contain pgbackrest::install
}
