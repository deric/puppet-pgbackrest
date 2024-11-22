# @summary Manages ini config on backup (repository) server
#
# @api private
#
class pgbackrest::config (
  Stdlib::AbsolutePath $config_dir = '/etc/pgbackrest',
  String               $config_file = 'pgbackrest.conf',
  String               $user = 'backup',
  String               $group = 'backup',
  Hash                 $config = {},
  Boolean              $show_diff = true,
) {
  # Deprecated location
  file { '/etc/pgbackrest.conf':
    ensure => absent,
  }

  $config_path = "${config_dir}/${config_file}"

  file { $config_dir:
    ensure => directory,
    owner  => $user,
    group  => $group,
  }

  file { $config_path:
    ensure  => file,
    owner   => $user,
    group   => $group,
    require => File[$config_dir],
  }

  $config.each |String $section, Hash $settings| {
    $settings.each |String $name, $value| {
      # Remove values not defined or empty
      $is_present = $value ? {
        undef   => 'absent',
        ''      => 'absent',
        default => 'present',
      }

      # Write the configuration options to pgbackrest::config::filename
      ini_setting { "${section} ${name}":
        ensure    => $is_present,
        path      => $config_path,
        section   => $section,
        setting   => $name,
        value     => $value,
        show_diff => $show_diff,
      }
    }
  }
}
