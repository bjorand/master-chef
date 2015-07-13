
package "libffi5"

include_recipe "rails"
include_recipe "mysql::server"

base_user node.redmine.user

warp_install node.redmine.user do
  rbenv true
end

mysql_database "redmine:database"

rails_app "redmine" do
  app_directory node.redmine.directory
  user node.redmine.user
  mysql_database "redmine:database"
end

unicorn_rails_app "redmine" do
  location node.redmine.location
  configure_nginx node.redmine.configure_nginx
end

git_clone "#{node.redmine.directory}/current" do
  user node.redmine.user
  repository node.redmine.git_url
  reference node.redmine.version
  notifies :restart, "service[redmine]"
end

directory "#{node.redmine.directory}/current/files" do
  owner node.redmine.user
  group node.redmine.user
  recursive true
end

link "#{node.redmine.directory}/current/config/database.yml" do
  to "#{node.redmine.directory}/shared/database.yml"
end

template "#{node.redmine.directory}/shared/configuration.yml" do
    variables :config => node.redmine
    source 'configuration.yml.erb'
    mode '0755'
end

link "#{node.redmine.directory}/current/config/configuration.yml" do
  to "#{node.redmine.directory}/shared/configuration.yml"
end

deployed_files = %w{Gemfile.local Gemfile.lock .ruby-version .rbenv-gemsets .bundle-option}

directory "#{node.redmine.directory}/shared/files" do
  owner node.redmine.user
end

deployed_files.each do |f|
  template "#{node.redmine.directory}/shared/files/#{f}" do
    owner node.redmine.user
    source f
  end
end

template "#{node.redmine.directory}/shared/files/config.ru" do
  owner node.redmine.user
  variables :location => node.redmine.location
  source "config.ru"
end

deployed_files << "config.ru"

cp_command = deployed_files.map{|f| "cp #{node.redmine.directory}/shared/files/#{f} #{node.redmine.directory}/current/#{f}"}.join(' && ')

ruby_rbenv_command "initialize redmine" do
  user node.redmine.user
  directory "#{node.redmine.directory}/current"
  code "rm -f .warped && #{cp_command} && rbenv warp install && bundle exec rake generate_secret_token && RAILS_ENV=production bundle exec rake db:migrate && RAILS_ENV=production REDMINE_LANG=fr bundle exec rake redmine:load_default_data"
  environment get_proxy_environment
  file_storage "#{node.redmine.directory}/current/.redmine_ready"
  version node.redmine.version
  notifies :restart, "service[redmine]"
end
