# @summary A PostgeSQL database instance to be backed up
#
# A description of what this class does
#
# @example
#   include pgbackrest::stanza
class pgbackrest::stanza(
  String                            $address       = $facts['fqdn'],
  Integer                           $port          = 5432,
  String                            $db_cluster    = 'main',
  ) {


}
