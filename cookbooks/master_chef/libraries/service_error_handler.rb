
class ServiceErrorHandler < Chef::Handler

  def initialize(service_name, pattern_for_process_kill)
    @service_name = service_name
    @pattern_for_process_kill = pattern_for_process_kill
  end

  def report
    return unless exception.to_s =~ /service\[#{@service_name}\]/
    puts "Starting service error handler for #{@service_name}"
    puts "*********************************************************"
    puts "Searching for config files to be deployed"
    all_resources.each do |r|
      notifs = r.delayed_notifications + r.immediate_notifications
      notifs.each do |n|
        if n.resource.name == @service_name && [:restart, :reload, :delayed_restart].include?(n.action) && r.action.class != Array
          action = r.action.to_sym
          unless action == :nothing
            run_action r, action
          end
        end
      end
      if r.class == Chef::Resource::DelayedExec && r.after_block_notifies
        r.after_block_notifies.each do |x|
          run_action r, :run if x[1].name == @service_name
        end
      end
    end
    puts "*********************************************************"
    return if node['no_restart_' +  @service_name]
    result = restart
    return if result == 0
    return if node['no_kill_' +  @service_name]
    puts "Trying to kill processes : #{@pattern_for_process_kill}"
    puts %x{pkill -f '#{@pattern_for_process_kill}'}
    restart
  end

  private

  def restart
    puts "Trying to restart service"
    puts %x{/etc/init.d/#{@service_name} start}
    result = $?.exitstatus
    puts "Result : #{result == 0 ? "OK" : "KO"} (#{result})"
    puts "*********************************************************"
    result
  end

  def run_action r, action
    puts "******** Find resource to deploy : #{r.class.name} #{r.name}, action #{action}"
    begin
      r.run_action action
    rescue Exception => e
      puts "Unable to run resource #{r.name} : ", e
    end
  end

end

