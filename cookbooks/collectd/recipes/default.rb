
package node.collectd.package_name do
  options "--no-install-recommends"
  version node.collectd[:package_version] if node.collectd[:package_version]
end

Chef::Config.exception_handlers << ServiceErrorHandler.new("collectd", ".*collectd.*")

service "collectd" do
  supports :status => true, :reload => true, :restart => true
  action auto_compute_action
end

directory node.collectd.config_directory do
  mode '0755'
end

template "/etc/collectd/collectd.conf" do
  mode '0644'
  source "collectd.conf.erb"
  variables :interval => node.collectd.interval
  notifies :restart, "service[collectd]"
end

directory node.collectd.bin

node.collectd.plugins.each do |name, config|
  collectd_plugin name do
    config config[:config] if config[:config]
  end
end

directory node.collectd.python_plugin.directory do
  owner 'root'
  group 'root'
  recursive true
end

incremental_template node.collectd.python_plugin.file do
  mode '0755'
  header <<-EOF
<LoadPlugin "python">
  Globals true
</LoadPlugin>
EOF
  header_if_block "<Plugin \"python\">"
  footer_if_block "</Plugin>"
  indentation 2
  notifies :restart, "service[collectd]"
end

directory "#{node.collectd.perl_plugin.directory}/Collectd/Plugins" do
  owner 'root'
  group 'root'
  recursive true
end

incremental_template node.collectd.perl_plugin.file do
  mode '0755'
  header <<-EOF
<LoadPlugin "perl">
  Globals true
</LoadPlugin>
EOF
  header_if_block <<-EOF
<Plugin "perl">
  IncludeDir "#{node.collectd.perl_plugin.directory}"
  BaseName "Collectd::Plugins"
EOF
  footer_if_block "</Plugin>"
  indentation 2
  notifies :restart, "service[collectd]"
end

incremental_template node.collectd.exec_plugin.file do
  mode '0755'
  header <<-EOF
LoadPlugin "exec"
EOF
  header_if_block "<Plugin \"exec\">"
  footer_if_block "</Plugin>"
  indentation 2
  notifies :restart, "service[collectd]"
end

delayed_exec "Remove useless collectd plugin" do
  after_block_notifies :restart, "service[collectd]"
  block do
    updated = false
    plugins = find_resources_by_name_pattern(/^#{node.collectd.config_directory}.*\.conf$/).map{|r| r.name}
    Dir["#{node.collectd.config_directory}/*.conf"].each do |n|
      unless plugins.include? n
        Chef::Log.info "Removing plugin #{n}"
        File.unlink n
        updated = true
      end
    end
    updated
  end
end
