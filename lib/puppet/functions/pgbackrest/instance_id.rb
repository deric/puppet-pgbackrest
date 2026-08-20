# frozen_string_literal: true

# Derives the cluster member id from a hostname suffix letter, so that
# cluster members named by the `<cluster><NN><member>` convention get
# a stable pg index: psql01a -> 1, psql01b -> 2, psql02a -> 1.
Puppet::Functions.create_function(:"pgbackrest::instance_id") do
  # @param hostname Host name or FQDN, e.g. 'psql01b' or 'psql01b.de.example.com'
  # @return Position in the alphabet of the letter following the trailing digits
  #   of the first dot-separated label ('a' => 1, 'b' => 2, ...).
  #   Returns 1 when the hostname has no such suffix (standalone server).
  # @example
  #   pgbackrest::instance_id('psql01a.de') # => 1
  #   pgbackrest::instance_id('psql01b.de') # => 2
  #   pgbackrest::instance_id('psql02a.de') # => 1
  dispatch :instance_id do
    param 'String[1]', :hostname
    return_type 'Integer[1,26]'
  end

  def instance_id(hostname)
    label = hostname.split('.').first
    m = label.downcase.match(%r{[0-9]+([a-z])$})
    return 1 if m.nil?

    (m[1].ord - 'a'.ord) + 1
  end
end
