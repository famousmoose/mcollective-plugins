module MCollective
  module Agent
    class DeployPackage
        @@valid_actions=['query', 'has', 'add', 'refresh', 'remove','upgrade']
      def initialize
        @search_path=''
      end
      def valid_actions ; @@valid_actions ; end
      def do_validate(action)
       
        return false unless @@valid_actions.include?(action)
        return respond_to?(action) 
      end

      def query
      #Our query code is common, only the location changes
        return false,"Unable to set search path" unless @search_path
        if File.directory?(search_path + '/release')
          Dir.entries(search_path + '/release').sort.each do |entry|
            versions.push(entry) unless entry =~ /^\.+$/
          end
        end
      # Depending on the software in questions, the trunk version of the files
        # can be in one of two locations
        ['', 'trunk/'].each do |base|
          if File.exists?(search_path + base + '/.revision')
            begin
              File.open(search_path + base + '/.revision') do |file|
                versions.push('trunk (' + file.gets.chomp +')')
              end
            rescue
              # If we cannot get the revision from the file, just add 'trunk'
              versions.push('trunk')
            end
          end
        end
        def warclean(path)
          require 'fileutils'
          target = '#{path}/webapps/ROOT/'
          FileUtils.rm_rf(target)
        end
        def wardeploy(warfile, path)
          #Clean up the webapp path and decompress our war file
          require 'fileutils'
          target = '#{path}/webapps/ROOT/'
          warclean(path)

          FileUtils.mkdir(target)
          #Call out to unzip. Maybe we should use libzip instead?
          system("unzip #{warfile} -d #{target}")
        end
      end  
    end
    #Now we define our packages
    #class 
    class We7<DeployPackage
      def initialize
        @search_path="/usr/local/tomcat-5.5.23/"
      end
    #valid actions in here
    end 
    class We7int<DeployPackage
      def initialize
        @search_path="/var/cache/tomcat6"
      end
    end
    class Waif<DeployPackage
      def initialize
        @search_path="/var/www/virtual/waif.we7c.net"
      end
    end
    class Assets<DeployPackage
      def initialize
        @search_path="/var/www/tomcat/assets"
      end
    end
    class Netlog<DeployPackage
      def initialize
        @search_path="var/www/virtual/nelog.devices.we7.com"
      end
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
            status,msg = worker.send("x{act}")
          end
        end
    end
  end
end
