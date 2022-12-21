# pgbackrest

Puppet module for managing PostgreSQL backups using `pgBackRest`.


## Usage

On database server
```puppet
include pgbackrest::stanza
```
configure backups schedule:

```yaml
pgbackrest::stanza::backups:
  eu-west-01: # host_group name
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
