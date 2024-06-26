# @api private
# @summary Install all required packages
#
class pgbackrest::install (
  String $ensure       = 'present',
  String $package_name = 'pgbackrest',
) {
  stdlib::ensure_packages(['pgbackrest'], {
      ensure  => $ensure,
  })
}
