# @summary Manages pgbackrest ini config
#
# Creates the configuration directories and writes options from `config`
# to the main configuration file. Options with `undef` or empty values are removed.
#
# @api private
#
# @param config_dir Main configuration directory
# @param config_subdir Included config (sub)dir
# @param config_file Main configuration file name
# @param user Unix account owning the configuration files
# @param group Unix group owning the configuration files
# @param config Configuration options keyed by ini section,
#   e.g. `{ 'global' => { 'process-max' => 8 } }`
# @param show_diff Whether changes to configuration values should be shown in reports/logs
#
class pgbackrest::config (
  Stdlib::AbsolutePath $config_dir = '/etc/pgbackrest',
  Stdlib::AbsolutePath $config_subdir = '/etc/pgbackrest/conf.d',
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

  file { $config_subdir:
    ensure  => directory,
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
