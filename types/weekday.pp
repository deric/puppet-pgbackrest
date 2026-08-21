# @summary Day of week of a cron schedule
#
# Accepts a single day (0-7, where both 0 and 7 mean Sunday), a cron expression
# string (e.g. `'*'`, `'1-5'`), or an array of days.
type Pgbackrest::Weekday = Variant[
                          Integer[0,7],
                          String,
                          Tuple[Variant[String, Integer[0,7]], 1, default]
                        ]
