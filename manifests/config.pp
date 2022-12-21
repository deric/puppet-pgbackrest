# @summary Manages ini config on backup (repository) server
#
# @api private
#
class pgbackrest::config(
  Stdlib::AbsolutePath $config_file = '/etc/pgbackrest.conf',
  String               $user = 'backup',
  String               $group = 'backup',
  Hash                 $config = {},
  Boolean              $show_diff = true,
  ){

  file { $config_file:
    ensure  => file,
    owner   => $user,
    group   => $group,
  }

  $config.each |String $section, Hash $settings| {
    $settings.each |String $name, String $value| {
      # Remove values not defined or empty
      $is_present = $value ? {
        undef   => 'absent',
        ''      => 'absent',
        default => 'present',
      }

      # Write the configuration options to pgbackrest::config::filename
      ini_setting { "${section} ${name}":
        ensure    => $is_present,
        path      => $config_file,
        section   => $section,
        setting   => $name,
        value     => $value,
        show_diff => $show_diff,
      }
    }
  }
}
