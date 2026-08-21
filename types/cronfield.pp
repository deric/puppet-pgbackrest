# @summary A cron schedule field
#
# Accepts a single integer, a cron expression string (e.g. `'*'`, `'*/15'`, `'8-18'`),
# or an array of those. Value ranges are validated by the `cron` resource itself.
type Pgbackrest::CronField = Variant[Integer, String, Array[Variant[Integer, String], 1]]
