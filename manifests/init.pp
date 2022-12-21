# @summary Common parameters for both repository and stanza
#
# Namespace for shared parameters.
#
# @param backup_user
#   Unix account used (mainly) for storing backups
#
# @example In order to disable ssh keys management on both stanza (db server) and repository (backup server)
#   pgbackrest::manage_ssh_key: false
#
class pgbackrest(
  Boolean              $manage_ssh_keys = false,
  Boolean              $manage_host_keys = true,
  Boolean              $manage_pgpass = true,
  Boolean              $manage_hba = true,
  Boolean              $manage_cron = true,
  Boolean              $purge_cron = true,
  String               $host_group = 'common',
  String               $host_key_type = 'ecdsa-sha2-nistp256',
  String               $package_name = 'pgbackrest',
  String               $package_ensure = 'present',
  String               $db_name = 'backup',
  String               $db_user = 'backup',
  String               $ssh_user = 'postgres',
  String               $backup_user = 'backup',
  String               $backup_group = 'backup',
  Stdlib::AbsolutePath $backup_dir = '/var/lib/pgbackrest',
  Stdlib::AbsolutePath $log_dir = '/var/log/pgbackrest',
  Stdlib::AbsolutePath $spool_dir = '/var/spool/pgbackrest',
  ) {

  class { 'pgbackrest::install':
    package_name => $package_name,
    ensure       => $package_ensure,
  }
}
