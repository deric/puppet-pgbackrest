# @summary Common parameters for both repository and stanza
#
# Namespace for shared parameters.
#
# @param manage_ssh_keys
# @param manage_host_keys
#    Whether ssh host keys should be exported from database server and imported on repository server
# @param manage_pgpass
# @param manage_hba
# @param manage_cron
# @param manage_user
# @param manage_package Whether package should be installed by puppet
# @param purge_cron
# @param host_group
# @param host_key_type
#   ssh host key fingerprint, one of 'ecdsa', 'ed25519' or 'rsa'. Default: `ed25519`
# @param package_name System package to be installed
# @param package_ensure `installed` or specific version. Exactly the same version needs to be on stanza and repository server.
# @param db_name
# @param db_user DB role for backup operations
# @param backup_user
# @param ssh_user
# @param backup_group Unix account used (mainly) for storing backups
# @param config_dir Main configuration directory
# @param config_subdir Included config (sub)dir
# @param backup_dir
# @param log_dir
# @param spool_dir
# @param password_encryption Either md5 or scram-sha-256
#
# @example In order to disable ssh keys management on both stanza (db server) and repository (backup server)
#   pgbackrest::manage_ssh_key: false
#
class pgbackrest (
  Boolean              $manage_ssh_keys = false,
  Boolean              $manage_host_keys = true,
  Boolean              $manage_pgpass = true,
  Boolean              $manage_hba = true,
  Boolean              $manage_cron = true,
  Boolean              $manage_package = true,
  Boolean              $manage_user = true,
  Boolean              $purge_cron = true,
  String               $host_group = 'common',
  Pgbackrest::HostKey  $host_key_type = 'ed25519',
  String               $package_name = 'pgbackrest',
  String               $package_ensure = 'present',
  String               $db_name = 'backup',
  String               $db_user = 'postgres',
  String               $ssh_user = 'postgres',
  String               $backup_user = 'pgbackup',
  String               $backup_group = 'pgbackup',
  Stdlib::AbsolutePath $config_dir = '/etc/pgbackrest',
  Stdlib::AbsolutePath $config_subdir = '/etc/pgbackrest/conf.d',
  Stdlib::AbsolutePath $backup_dir = '/var/lib/pgbackrest',
  Stdlib::AbsolutePath $log_dir = '/var/log/pgbackrest',
  Stdlib::AbsolutePath $spool_dir = '/var/spool/pgbackrest',
  Postgresql::Pg_password_encryption $password_encryption = 'md5',
) {
  if $manage_package {
    class { 'pgbackrest::install':
      package_name => $package_name,
      ensure       => $package_ensure,
    }
  }
}
