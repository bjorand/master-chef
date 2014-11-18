
define :tomcat_instance, {
  :war_url => nil,
  :war_location => nil,
  :xml_config_file => nil,
  :override => {},
} do

  tomcat_instance_params = params

  config = tomcat_config tomcat_instance_params[:name]

  config = config.deep_merge tomcat_instance_params[:override]

  instance_name = config[:name]

  catalina_base = "#{node.tomcat.instances_base}/#{config[:name]}"

  [
    catalina_base,
    "#{catalina_base}/temp",
    "#{catalina_base}/webapps",
    "#{catalina_base}/work",
    "#{node.tomcat.log_dir}/#{config[:name]}"
    ].each do |d|
    directory d do
      owner node.tomcat.user
    end
  end

  execute "copy config #{catalina_base}/conf" do
    user node.tomcat.user
    command "cp -r #{node.tomcat.catalina_home}/conf #{catalina_base}/conf && rm #{catalina_base}/conf/server.xml"
    not_if "[ -d #{catalina_base}/conf ]"
  end

  link "#{catalina_base}/logs" do
    owner node.tomcat.user
    to "#{node.tomcat.log_dir}/#{config[:name]}"
  end

  template "/etc/init.d/#{config[:name]}" do
    cookbook "tomcat"
    source "init_d.erb"
    mode '0755'
    variables({
      :catalina_base => catalina_base,
      :catalina_home => node.tomcat.catalina_home,
      :name => config[:name],
      :user => node.tomcat.user,
      :tmp_dir => config[:tmp_dir] || "/tmp/tomcat6-tmp-#{config[:name]}"
      })
  end

  Chef::Config.exception_handlers << ServiceErrorHandler.new(config[:name], catalina_base)

  service config[:name] do
    supports :status => true, :restart => true, :reload => true, :graceful_restart => true
    action auto_compute_action
  end

  template "#{catalina_base}/conf/env" do
    cookbook "tomcat"
    source "env.erb"
    owner "tomcat"
    mode '0644'
    variables :config => config
    notifies :restart, "service[#{config[:name]}]"
  end

  major_version = node.tomcat.version.split('.').first

  template "#{catalina_base}/conf/server.xml" do
    cookbook "tomcat"
    source "server_#{major_version}.xml.erb"
    owner node.tomcat.user
    variables :config => config
    notifies :restart, "service[#{config[:name]}]"
  end

  if tomcat_instance_params[:war_location] && tomcat_instance_params[:war_url]

     execute_version "install war from #{tomcat_instance_params[:war_url]}" do
      user node.tomcat.user
      command "curl -s -f -L #{tomcat_instance_params[:war_url]} -o /tmp#{tomcat_instance_params[:war_location]}.war && mv /tmp#{tomcat_instance_params[:war_location]}.war #{catalina_base}/webapps#{tomcat_instance_params[:war_location]}.war"
      environment get_proxy_environment
      version tomcat_instance_params[:war_url]
      or_only_if ["[ ! -f #{catalina_base}/webapps#{tomcat_instance_params[:war_location]}.war ]"]
      file_storage "#{catalina_base}/.war_version"
    end

  end

  if tomcat_instance_params[:xml_config_file]

    directory "#{catalina_base}/conf/Catalina/localhost" do
      recursive true
      owner node.tomcat.user
    end

    template "#{catalina_base}/conf/Catalina/localhost/#{tomcat_instance_params[:xml_config_file][:name]}" do
      cookbook tomcat_instance_params[:xml_config_file][:cookbook] if tomcat_instance_params[:xml_config_file][:cookbook]
      source tomcat_instance_params[:xml_config_file][:source] if tomcat_instance_params[:xml_config_file][:source]
      owner node.tomcat.user
      variables tomcat_instance_params[:xml_config_file][:variables] if tomcat_instance_params[:xml_config_file][:variables]
      notifies :restart, "service[#{config[:name]}]"
    end

  end

  node.set[:tomcat][:instances][tomcat_instance_params[:name]] = {
    :war => "#{catalina_base}/webapps#{tomcat_instance_params[:war_location]}.war",
    :base => catalina_base,
    :logs => "#{catalina_base}/logs",
  }

end