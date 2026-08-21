# @summary Day of month of a cron schedule
#
# Accepts a single day (1-31), a cron expression string (e.g. `'*'`, `'*/2'`, `'1-15'`),
# or an array of days.
type Pgbackrest::Monthday = Variant[
                          Integer[1,31],
                          String,
                          Tuple[Variant[String, Integer[1,31]], 1, default]
                        ]
