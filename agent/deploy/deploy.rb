module MCollective
  module Agent
    class DeployPackage
        @@valid_actions=['query', 'has', 'add', 'refresh', 'remove','upgrade']
      def valid_actions ; @@valid_actions ; end
      def do_validate(action)
       
        return false unless @@valid_actions.include?(action)
        return respond_to?(action) 
      end
    end
    #Now we define our packages
    #class 
    class We7<DeployPackage
    end 

    class Deploy<RPC::Agent
      metadata :name        => "deploy",
               :description => "Agent to deploy our website, including Assets and Tomcat files.",
               :author      => "Jonathan Wright <jonathan@we7.com>",
               :license     => "Private",
               :version     => "1.0.0",
               :url         => "http://wiki.we7.com/mcollective/deploy",
               :timeout     => 300


        # Extract the variables we need
        
        prototype = DeployPackage.new
        prototype.valid_actions.each do |act|
          action act do
            version = request[:version]
            target = request[:target]
            
            reply.fail! "target #{target} not available!" unless Agent.const_defined?(target.capitalize) && Agent.const_get(target.capitalize).class.is_a?(Class)
            worker = Agent.const_get(target.capitalize).new
            reply.fail!("Command not valid for target") unless worker.do_validate("act")
            worker.send("x{act}")
          end
        end
    end
  end
end
