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

repository config:
```yaml
pgbackrest::repository::host_group: eu-west
pgbackrest::repository::config:
  global:
    repo1-path: /backup/pgbackrest
    repo1-retention-full: 1
    log-level-console: info
    log-level-file: detail
    start-fast: 'y'
    delta: 'y'
    backup-standby: 'y'
    archive-timeout: 3600
  global:archive-push:
    compress-level: 3
    compress-type: lz4
```

## Primary with replicas (standby servers)

All members of a PostgreSQL cluster share one stanza. Set the same `cluster`
name on every member and give each one a unique `id` (the pg index used in the
repository configuration). The member with `id: 1` is considered the primary
and is the only one exporting per-cluster resources (backup cron jobs and the
`stanza-create` command); this can be overridden with the `primary` parameter.

Primary (psql01a):
```yaml
pgbackrest::stanza::cluster: psql01
pgbackrest::stanza::id: 1
pgbackrest::stanza::backups:
  eu-west:
    incr:
      hour: 3
```

Standby (psql01b) — declare the same `backups` host groups (this assigns the
repositories; schedules are only exported by the primary):
```yaml
pgbackrest::stanza::cluster: psql01
pgbackrest::stanza::id: 2
pgbackrest::stanza::backups:
  eu-west:
    incr:
      hour: 3
```

Each member exports its own `conf.d/<cluster>-<hostname>.conf` file to the
repository containing only its `pg<id>-*` options. pgBackRest merges all files
in `conf.d`, so the repository ends up with a single stanza section:

```ini
[psql01]
pg1-host = psql01a.example.com
...
pg2-host = psql01b.example.com
...
```

To take backups from the standby instead of the primary, set
`backup-standby: 'y'` in the repository's `global` config section.

Caveats:
- Role passwords are replicated from the primary, so when `manage_pgpass` is
  enabled set the same `db_password` (or `seed`) on all members, otherwise
  the standby exports a `.pgpass` entry with a password that doesn't match.
- Remove any hand-managed stanza section for the same cluster from the
  repository configuration, otherwise pgBackRest may see duplicated options.

## How Does This Work

### pgbackrest::stanza

Should be included on a database server. Exported statements are not executed on `stanza` (database) server, but will be collected by an assigned `repository` with matching `host_group` (if exists).

- **Install** `pgbackrest` package
- **Generate** ssh keys (if given ssh key doesn't exist) and export public ssh key (only if `pgbackrest::manage_ssh_keys: true`), default: `false`
- Export host ssh key (only if `pgbackrest::manage_host_keys: true`), default: `true`
- **Create** a PostgreSQL user `pgbackrest::db_user` and database `pgbackrest::db_name` with randomly generated password, default user: `backup` (when `pgbackrest::stanza::manage_dbuser: true`)
- Export username and password for `.pgpass` file
- **Grant** `pgbackrest::db_user` necessary permissions for executing `pg_basebackup` and allow connection from repository server (when `pgbackrest::manage_hba: true`)
- Export `pgbackrest stanza-create` command
- Export cron configs for backup jobs
- **Import** host ssh key of `repository` server matching the `host_group` (if `pgbackrest::manage_host_keys: true`)
- **Import** public ssh key of `repository` server matching the `host_group`

### pgbackrest::repository

Repository is a server where backups are stored (though could be located on the same server).

- **Install** `pgbackrest` package
- **Generate** ssh keys (if given ssh key doesn't exist) and export public ssh key (only if `pgbackrest::manage_ssh_keys: true`), default: `false`
- **Create** local unix account `pgbackrest::backup_user`
- **Create** directories for storing backups, logs, temporary data


## Common params

- `pgbackrest::backup_dir` directory where backups will be stored

## Caveats

- This module does NOT manage firewall rules
- At least two Puppet runs are required to apply all configuration.
