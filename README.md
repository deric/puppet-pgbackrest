# pgbackrest

Puppet module for managing PostgreSQL backups using `pgBackRest`.

## Basic Usage

On database server
```puppet
include pgbackrest::stanza
```
configure backups schedule:

```yaml
pgbackrest::stanza::backups:
  eu-west: # host_group name
    incr:
      hour: 3
      minute: 50
      weekday: [0-1,3-6] # every day except Tuesday
    full:
      hour: 1
      minute: 10
      weekday: 2 # Tuesday full backup
```

On storage (backup) server:

```puppet
include pgbackrest::repository
```

## How Does This Work

### pgbackrest::stanza

Should be included on a database server. Exported statements are not executed on `stanza` (database) server, but will be collected by an assigned `repository` with matching `host_group` (if exists).

- **Generate** ssh keys (if given ssh key doesn't exist) and export public ssh key (only if `pgbackrest::manage_ssh_keys: true`), default: `false`
- Export host ssh key (only if `pgbackrest::manage_host_keys: true`), default: `true`
- **Create** a PostgreSQL user `pgbackrest::db_user` and database `pgbackrest::db_name` with randomly generated password, default user: `backup` (when `pgbackrest::stanza::manage_dbuser: true`)
- Export username and password
- **Grant** `pgbackrest::db_user` necessary permissions for executing `pg_basebackup` and allow connection from repository server (when `pgbackrest::manage_hba: true`)
- Export `pgbackrest stanza-create` command
- Export cron configs for backup jobs
- **Import** host ssh key of `repository` server with the same `host_group` (if `pgbackrest::manage_host_keys: true`)
- **Import** public ssh key of `repository` server with the same `host_group`

### pgbackrest::repository

Repository is a server where backups are stored (though could be located on the same server).

-

## Common params

- `pgbackrest::backup_dir` directory where backups will be stored
