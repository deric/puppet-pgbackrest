# @api private
# @summary Install all required packages
#
# @param ensure Package ensure value, `present` or a specific version
# @param package_name System package to be installed
#
class pgbackrest::install (
  String $ensure       = 'present',
  String $package_name = 'pgbackrest',
) {
  stdlib::ensure_packages(['pgbackrest'], {
      ensure  => $ensure,
  })
}
