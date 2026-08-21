# Changelog

All notable changes to this project will be documented in this file.

## Release 1.0.0 [2026-08-21]

**Features**

- Remote backups: the backup server connects to database servers over SSH and pulls backups ([#6](https://github.com/deric/puppet-pgbackrest/pull/6))
- Support for standby servers; whether a stanza is primary is detected via an SQL query ([#6](https://github.com/deric/puppet-pgbackrest/pull/6))
- Backups run under a low-privileged unix account (`pgbackup`) on the database server by default ([#4](https://github.com/deric/puppet-pgbackrest/pull/4))
- Each cluster's configuration is stored in a dedicated file, `${cluster}-${id}.conf` ([#2](https://github.com/deric/puppet-pgbackrest/pull/2), [#6](https://github.com/deric/puppet-pgbackrest/pull/6))
- New `pgbackrest::instance_id` function assigns a unique numeric id per instance; `id` is now a numeric identifier while `hostname` identifies the host ([#4](https://github.com/deric/puppet-pgbackrest/pull/4), [#6](https://github.com/deric/puppet-pgbackrest/pull/6))
- Arbitrary pgBackRest config options can be passed to both `repository` and `stanza` ([#6](https://github.com/deric/puppet-pgbackrest/pull/6))
- Support setting `archive_command` ([#4](https://github.com/deric/puppet-pgbackrest/pull/4))
- Support setting `password_encryption` and a rule for local connections
- The pgBackRest package installation can optionally be managed by Puppet
- Backup user's password is stored locally (`.pgpass`) on the database server
- Default compression switched to `zst` (lower CPU usage)
- Simplified cron field definitions; negative compress levels allowed; compression is not set when `none` is requested ([#6](https://github.com/deric/puppet-pgbackrest/pull/6), [#8](https://github.com/deric/puppet-pgbackrest/pull/8))
- `max-processes` is no longer set explicitly, so it can be inherited from `[global]` config ([#8](https://github.com/deric/puppet-pgbackrest/pull/8))
- Debian 13 support; allow puppet/systemd up to 10.x

**Bugfixes**

- Only a single cron job is scheduled per stanza instead of one per replica ([#7](https://github.com/deric/puppet-pgbackrest/pull/7))
- Stanza is not re-created when it already exists ([#6](https://github.com/deric/puppet-pgbackrest/pull/6))
- Fixed importing SSH keys on the backup server and exported SSH key username ([#4](https://github.com/deric/puppet-pgbackrest/pull/4), [#6](https://github.com/deric/puppet-pgbackrest/pull/6))
- Fixed passing pgBackRest version; removed unsupported `--config-path` argument
- Fixed invalid backup type ([#8](https://github.com/deric/puppet-pgbackrest/pull/8))
- Declared correct module dependencies, including transitive `puppetlabs/concat` ([#8](https://github.com/deric/puppet-pgbackrest/pull/8), [#9](https://github.com/deric/puppet-pgbackrest/pull/9))

**Breaking changes**

- Requires Puppet >= 8.0.0
- Requires puppetlabs/postgresql >= 10.0.0, puppetlabs/inifile >= 6.1.0, puppet/systemd >= 6.0.0, puppetlabs/sshkeys_core >= 2.4.0; new dependency on puppetlabs/concat >= 9.0.0

