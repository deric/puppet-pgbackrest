# @summary Hour of a cron schedule
#
# Accepts a single hour (0-23), a cron expression string (e.g. `'*'`, `'*/6'`, `'8-18'`),
# or an array of hours.
type Pgbackrest::Hour = Variant[
                          Integer[0,23],
                          String,
                          Tuple[Variant[String, Integer[0,23]], 1, default]
                        ]
