# @summary Minute of a cron schedule
#
# Accepts a single minute (0-59), a cron expression string (e.g. `'*'`, `'*/15'`, `'0-30'`),
# or an array of minutes.
type Pgbackrest::Minute = Variant[
                          Integer[0,59],
                          String,
                          Tuple[Variant[String, Integer[0,59]], 1, default]
                        ]
