
define :git_clone, {
  :reference => nil,
  :user => nil,
  :repository => nil,
  :notifies => nil,
  :clean_ignore => true,
} do

  git_clone_params = params

  raise "Please specify reference for using git_clone" unless git_clone_params[:reference]
  raise "Please specify user for using git_clone" unless git_clone_params[:user]
  raise "Please specify repository for using git_clone" unless git_clone_params[:repository]

  if node.git.auto_use_http_for_github && (ENV['BACKUP_http_proxy'] || node[:no_external_ssh] || node.git[:force_use_http_for_github]) && git_clone_params[:repository] =~ /^git:\/\/(github.com.*)/
    git_clone_params[:repository] = "http://#{$1}"
  end

  use_proxy = git_clone_params[:repository].match(/^http/)

  execute "git clone #{git_clone_params[:repository]} to #{git_clone_params[:name]}" do
    user git_clone_params[:user]
    command "git clone -q #{git_clone_params[:repository]} #{git_clone_params[:name]}"
    environment get_proxy_environment if use_proxy
    not_if "[ -d #{git_clone_params[:name]}/.git ]"
  end

  execute "create branch #{git_clone_params[:repository]} to #{git_clone_params[:name]}" do
    user git_clone_params[:user]
    command "cd #{git_clone_params[:name]} && git checkout -q -b deploy"
    environment get_proxy_environment if use_proxy
    not_if "cd #{git_clone_params[:name]} && git branch | grep deploy"
    notifies *git_clone_params[:notifies] if git_clone_params[:notifies]
  end

  clean_options = "-q -d -f"
  clean_options += " -x" if git_clone_params[:clean_ignore]

  sha = git_clone_params[:reference]
  sha = "`git ls-remote #{git_clone_params[:repository]} '#{sha}' '#{sha}^{}' | tail -n 1 | awk '{print $1}'`" unless sha =~ /^[0-9a-f]{40}$/

  env_for_not_if = use_proxy ? get_proxy_environment : {}

  execute "check remote for #{git_clone_params[:name]}" do
    command "cd #{git_clone_params[:name]} && git remote rm origin && git remote add origin #{git_clone_params[:repository]}"
    not_if "cd #{git_clone_params[:name]} && git remote -v | grep origin | grep #{git_clone_params[:repository]}"
  end

  execute "update git clone of #{git_clone_params[:repository]} to #{git_clone_params[:name]}" do
    user git_clone_params[:user]
    command "cd #{git_clone_params[:name]} && git fetch -q origin && git fetch --tags -q origin && git reset -q --hard #{sha} && git clean #{clean_options} && git log -n1 --decorate | head -n 1 | grep #{sha}"
    environment get_proxy_environment if use_proxy
    not_if "cd #{git_clone_params[:name]} && git log -n1 --decorate | head -n 1 | grep #{sha}", :environment => env_for_not_if
    notifies *git_clone_params[:notifies] if git_clone_params[:notifies]
  end

end