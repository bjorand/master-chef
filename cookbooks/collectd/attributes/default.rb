default[:collectd][:plugins] = {
  "cpu" => {},
  "df" => {},
  "disk" => {},
  "entropy" => {},
  "interface" => {},
  "irq" => {},
  "memory" => {},
  "processes" => {},
  "swap" => {},
  "users" => {},
  "syslog" => {:config => "LogLevel \"info\""}
}
default[:collectd][:package_name] = "collectd-core"
default[:collectd][:interval] = 10
default[:collectd][:config_directory] = "/etc/collectd/collectd.d"
default[:collectd][:bin] = "/opt/collectd/bin"

default[:collectd][:python_plugin] = {
  :directory => "/opt/collectd/lib/collectd/plugins/python",
  :file => "/etc/collectd/collectd.d/python.conf"
}

default[:collectd][:perl_plugin] = {
  :directory => "/opt/collectd/lib/collectd/plugins/perl",
  :file => "/etc/collectd/collectd.d/perl.conf"
}

default[:collectd][:exec_plugin] = {
  :file => "/etc/collectd/collectd.d/exec.conf"
}