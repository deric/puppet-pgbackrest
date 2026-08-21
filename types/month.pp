# @summary Month of a cron schedule
#
# Accepts a single month (1-12), a cron expression string (e.g. `'*'`, `'*/3'`, `'1-6'`),
# or an array of months.
type Pgbackrest::Month = Variant[
                          Integer[1,12],
                          String,
                          Tuple[Variant[String, Integer[1,12]], 1, default]
                        ]
