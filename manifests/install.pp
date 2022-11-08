# @api private
# @summary Install all required packages
#
class pgbackrest::install(
  String $ensure = 'present',
  ) {

  ensure_packages(['pgbackrest'], {
      ensure  => $ensure,
    })
}
