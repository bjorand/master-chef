
if node[:ssh_keys]

  node.set[:resolved_ssh_keys] = {}

  node.ssh_keys.each do |name, config|

    if config["users"] || config["optional_users"]
      unless config["disabled"]
        users = []
        if config["users"]
          config["users"].each do |user|
            users << user
          end
        end
        if config["optional_users"]
          config["optional_users"].each do |user|
            users << user if get_home(user, true) && !users.include?(user)
          end
        end
        users.each do |user|
          node.set[:resolved_ssh_keys][user] = [] unless node.resolved_ssh_keys[user]
          node.set[:resolved_ssh_keys][user] = node.resolved_ssh_keys[user] + config["keys"] if config["keys"]
          if config["ref"]
            config["ref"].each do |k|
              raise "Unable to find keys for user #{k}" unless node.ssh_keys[k]
              node.set[:resolved_ssh_keys][user] = node.resolved_ssh_keys[user] + (node.ssh_keys[k]["keys"] || [])
            end
          end
        end
      end
    end

  end

  node.resolved_ssh_keys.each do |user, keys|

    dir = ssh_user_directory user do
      action :nothing
    end

    file "#{get_home user}/.ssh/authorized_keys" do
      owner user
      mode '0700'
      content keys.uniq.sort.join("\n")
      action :nothing
    end

    # we have to use delayed exec because users are often created after this recipe
    delayed_exec "authorized_keys for user #{user}" do
      after_block_notifies :create, "directory[#{get_home user}/.ssh]" if dir
      after_block_notifies :create, "file[#{get_home user}/.ssh/authorized_keys]"
    end

  end

end
