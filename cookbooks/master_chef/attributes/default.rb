
unless ENV['NO_MASTER_CHEF_CONFIG']

  config_file = ENV['MASTER_CHEF_CONFIG']

  raise "Please specify config file with env var MASTER_CHEF_CONFIG" unless config_file
  raise "File not found #{config_file}" unless File.exists? config_file

  config = JSON.load(File.read(config_file))

  node_config = config["node_config"]

  if node_config
    node_config.each do |k, v|
      normal[k] = v
    end
  end

end

default[:master_chef][:chef_solo_scripts] = {
  :user => "chef",
  :logging => {
    :command_line => "--force-formatter",
    :solo_rb => <<-EOF
verbose_logging false
Mixlib::Log::Formatter.show_time = false
EOF
  },
  :no_git_cache => false,
}

default[:local_storage] = {
  :file => "/opt/master-chef/var/local_storage.yml",
  :owner => "root",
}

default[:tcp_port_manager][:range] = 18000..20000
