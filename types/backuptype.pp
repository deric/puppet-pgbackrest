# @summary Type of backup, passed to `pgbackrest backup --type`
type Pgbackrest::BackupType = Enum['full','incr','diff']
