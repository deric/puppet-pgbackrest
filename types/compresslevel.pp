# @summary Compression level (valid range: -7 to 22)
#
# Negative values are supported only by `zst` compression.
type Pgbackrest::CompressLevel = Integer[-7,22]
