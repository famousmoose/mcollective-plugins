# vim:ft=ruby:tw=80:
# ------------------------------------------------------------------------------
# deploy.rb
# We7 deployment agent for website and associated assets
#
#   (c) 2011 onwards, Jonathan Wright <jonathan@we7.com>
# ------------------------------------------------------------------------------
# Changelog
#   - 1.0 - Initial Release (currently only supports Assets deployment)

# We need Net::HTTP to download the torrent file, and sockets to get addresses
require 'net/http'
require 'socket'
# We need to do base64 decoding to create the .torrent file we've been send to
# download the package file (if required)
require 'base64'
# We would also like to allow any torrent to be seeded by this application for
# short period after (usually around 30 seconds), which can be done in a
# separate thread.
require 'thread'
require 'timeout'
# We need these to extract files on the system
require 'zip/zip'
class NilClass
  def empty?;nil?;end
end
module MCollective
  module Agent
    # This is the master class for deployment targets. It's used in a basic
    # capacity to validate the action requested of the target (the subclass),
    # whereby the action is an implmentation through a method.
    class DeployPackage
      # List of overall valid actions. Although a class may only implement a
      # subset of these, this is the superset of those allowed.
      @@valid_actions = ['query', 'has', 'add', 'refresh', 'remove','upgrade']
      # Plus an accessor (we can't use attr_read as it's a Class variable)
      def self.valid_actions; @@valid_actions; end
      # Also set the location of the tracker which we will need to connect to
      # along with the amount of time we can spend re-seeding the package back
      # to other agents in the process
      @@timeout       = 30

      # When we create the class, we need the version and package information in
      # order for the actions to be able complete their task. We'll do this on
      # creation of the class. This will simplify the dymanic calling of the
      # action.
      def initialize(reply, logger, version = nil, package = nil)
        # Put variables we've recivied into their class variables
        @reply = reply; @logger = logger; @version = version;
        # Also create additional class variables for extracted data
        @package = nil; @torrent = nil; @tracker = nil
        # If we have something in package, then split it into it's name and
        # and the base64 encoded version of the torrent data.
        unless package.empty?
          begin
            # The base64 encoded version of the data will be a hash array which
            # contains the binary data of .torrent file along with the tracker
            # we need to connect to; extract that information
            data = Marshal.restore(Base64.decode64(package))
            @package = data[:package]
            @torrent = data[:torrent]
            @tracker = data[:tracker]
          rescue => e
            # If we can't, then we cannot continue any further
            raise DeployFail, "Unable to extract torrent information: #{e}"
          end
        end
      end

      # As part of the checked, we need to be able to validate that an action
      # can be performed; first check it against the above set then see if the
      # class for this :target has a method to implement the action.
      def do_validate(action)
        return false unless @@valid_actions.include?(action)
        return respond_to?(action)
      end

      private

      # We need to create secure temporary directories where we can put files as
      # we recieive and/or download them. This method will generate a random
      # string and try to create a directory with it
      def create_tmp
        # Generate a set of characters we can use in the name of the directory
        chars = [('0'..'9'),('a'..'z'),('A'..'Z')].map{ |i| i.to_a }.flatten
        25.times do
          # We'll make up to 25 attempts, but generate a directory name with 10
          # random characters in it and test to see if it's already in use. If
          # so, skip to the next one,
          tmp = '/tmp/deploy.' + 10.times.map{ chars[rand(chars.length)] }.join
          next if File.directory?(tmp) or File.exists?(tmp)
          # Otherwise log it, create it and return what we've found
          @logger.debug "Using temporary directory: #{tmp}"
          return FileUtils.mkdir(tmp);
        end
        # If we get to here, then we couldn't create a direc'ory and therefore
        # we cannot continue any further
        raise DeployFail, 'Cannot create temporary directory'
      end

      # When connecting to the transfer, Murder needs to know which IP address
      # to use. This will create a UDP socket to the address given and determine
      # which local IP address will be used.
      def get_address(tracker)
        # Begin by turning off reverse DNS lookup temporarily (even if it's off)
        orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true
        # Create a UDP socket to the internal tracker and get the IP address
        # the system will use to open that connection.
        UDPSocket.open { |s| s.connect tracker, 1; s.addr.last }
      ensure
        # Always ensure that the reverse DNS setting is restored
        Socket.do_not_reverse_lookup = orig
      end

      # This is the magic bit: This method extracts the .torrent file and then
      # downloads the package from the various seeders via our tracker, before
      # re-seeding it back out for a short period afterwards.
      def get_package(tmp)
        # Use the package name to generate the name of the .torret we'll save
        # the data passed to us in (this will specifically split by the last
        # period in the filename, taking into account any .gz/.bz2 double
        # extension types if we use that format)
        torrent = "#{tmp}/#{@package.split(/\.([^.]*(\.(gz|bz2))?)$/).first}.torrent"
        File.open(torrent, 'w') { |f| f.write(@torrent) }
        # Setup the rest of the details we need, including the package and
        # address we'll use to connect to the tracker
        package = "#{tmp}/#{@package}"
        address = get_address(@tracker.split(':',2).first)
        # Make a note of these
        @logger.debug "Started fetch of #{@package} via #{@tracker}"
        # Now run Murder. In this instance, we'll wait until it's completed
        if system("/usr/sbin/murder_client peer #{torrent} #{package} #{address}")
          # If we have a successful fetch, start seeding and then return the
          # location of the file we've downloaded
          @logger.debug "Fetch successful"
          # seed_package(torrent, package, address)
          package
        else
          # If Murder doesn't finish cleanly, we'll assume something has gone
          # wrong and abort
          @logger.debug "Fetch failed!"
          raise DeployFail, "Retrieval of #{@package} failed"
        end
      end

      # When we've downloaded the package, it would be nice to seed it
      # afterwar's as well. This method will do that by creating a separate
      # thread for it and then allowing a maximum runtime of 30 seconds for it.
      def seed_package(torrent, package, address)
        # Now being a temporary re-seeding of the package we have received
        @logger.debug "Starting temporary seed of #{@package} via #{@tracker} for #{@@timeout} seconds"
        begin
          # This needs to be done in a separate thread as so not to interfere
          # with remainder of the deployment
          @thread = Thread.new {
            begin
              # We'll also wrap this in a Timeout class; this will make sure
              # that the program will only run for around 30 seconds before
              # aborting it's execution.
              status = Timeout::timeout(@@timeout) {
                system("/usr/sbin/murder_client seed #{torrent} #{package} #{address}")
              }
              @logger.debug "Failed to start seeding of #{@package}"
            rescue Timeout::Error => e
              # We should always reach this section as the program as once the
              # timeout it reached Timeout::Error is raised
              @logger.debug "Completed temporary seeding of #{@package}"
            end
          }
        rescue => e
          # If we can't start the tread, we won't worry. Just make a note of it
          @logger.debug "Could not start thread for seeding #{@package}"
          @thread = nil
        end
      end

      # If we want to wait on the seeding thread to finish, call this method
      # which will handle it for you.
      def seed_wait
        # We may want to wait on the seed_package thread to finish, in which case
        # first check that we have a thread running
        return false unless @thread
        # If so, wait on it to finish and join it back into the main thread
        begin
          @logger.debug "Waiting on seeding thread for #{@package} to finish"
          @thread.join
        rescue => e
          # If anything goes wrong with this, then we'll ignore it
          false
        end
      end

      def extract(package, location)
        case package.split(/\.([^.]*(\.(gz|bz2))?)$/)[1,]
        # At the moment, there are no read libraries to handle this internally,
        # so we'll export this
        when 'tar.gz','tar.bz2','tgz','tbz2'
          key = (package[-2,2] == 'gz' ? 'z' : 'j')
          raise DeployFail, "Unable to extract #{File.basename(package)} to #{location}" unless system("/bin/tar #{key}xf --directory=#{location} #{package}") 
        when 'zip','war'
          begin
            # Open the .zip file and then extract each file to the location
            # required, making sure the directory exists first
            Zip::ZipFile.open(package) do |zip|
              zip.each do |file|
                to = File.join(location, file.name)
                FileUtils.mkdir_p(File.dirname(to))
                file.extract(to) unless File.exist?(to)
              end
            end
          
          # If something goes wrong, catch it and re-raise a new exception
          rescue => e
            raise DeployFail, "Could not unzip #{File.basename(package)} to #{location}: #{e}"
          end
        else
          # If the extension is anything else, we don't know how to extract it,
          # so we should abort before continuing.
          @logger.debug "Couldn't determing how to extract #{file}"
          raise DeployFail, "Do not know how to extract #{package}"
        end
      end

      def initdService(service, command)
        return false unless ['stop','start','restart','status'].include?(command)
        system("/etc/init.d/#{service} start")
      end
    end

    # This is a local class which is used to raise errors with fetching the
    # Packages and is used more as a symbol than any specific function.
    class DeployFail<RuntimeError; end
    # Our tomcat deployment code is basically common between all tomcat versions
    class Tomcat<DeployPackage
      def catalinaClean(path)
        require 'fileutils'
        target = '#{path}/work/Catalina/localhost/'
        FileUtils.rm_rf(target)
      end
      def warClean(path)
        require 'fileutils'
        target = '#{path}/webapps/ROOT/'
        FileUtils.rm_rf(target)
      end
      def tomcat_version ;end
      def app_path; end
      def has
        version = nil
        manifest = File.new('#{app_path}/webapps/ROOT/META-INF/MANIFEST.MF',:r)
        begin
          while (line = manifest.gets)
            version = $1 if line.match(/^Implementation-Version: (.*)$/
          end
        rescue => err
        ensure
          manifest.close unless manifest.nil?
        end
        version
      end

      def upgrade
      #Shutdown tomcat, clean out, redeploy and restart
      #For full and Rolling deployments
          tmp = create_tmp
          #package = get_package(tmp)
          package = ''
          #Stop tomcat
          initdService(tomcat_version, :stop)
          #Cleanups
          catalinaClean(app_path)
          warClean(app_path)
          extract(package,"#{app_path}/webapps/ROOT/")
          #Start tomcat again
          initdService(tomcat_version, :start)
      end
      def refresh
      #redeploy our webapp without deleting first
      #This is for copy webpages
          tmp = create_tmp
          package = get_package(tmp)
          #Might want to catalinaClean here?
          extract(package,"#{@search_path}/webapps/ROOT/")
      end
    end
    # Create a Class which will handle the deployment of the we7 Classic website
    class We7<Tomcat
        def app_path 
          "/usr/local/tomcat-5.5.23/"
        end
        def tomcat_version
          "tomcat5"
        end
    end 

    class We7int<Tomcat
      def app_path
        "/var/cache/tomcat6"
      end
      def tomcat_version
        "tomcat6"
      end
    end

    class Waif<DeployPackage
        @@app_path="/var/www/virtual/waif.we7c.net"
    end

    class Netlog<DeployPackage
        @@app_path="var/www/virtual/nelog.devices.we7.com"
    end

    # Create a Class which will handle the deployment (and management) of the
    # assets for both versions of the websites
    class Assets<DeployPackage
      # Where is the assets directory located?
      @@assets_dir = '/var/www/tomcat/assets'

      def query
        # Create an array which will hold everything we find
        found = []
        # Now go into the assets directory and look for the all the directories
        # in there which are two letters, then within that, look for any
        # directories which are five-six numbers. Anything found add to the
        # array created above
        Dir.chdir(@@assets_dir) do
          Dir.entries('.').each do |directory|
            # Ignore . and ..
            next if /^\.+$/.match(directory) or not /^[a-zA-Z]{2}$/.match(directory)
            # Ignore anything that isn't a directory
            next unless File.directory?("#{@@assets_dir}/#{directory}")
            # Now do the numbered directories
            Dir.entries(directory).each do |version|
              # Same as above for these directories
              next if /^\.+$/.match(version) or not /^[0-9]{5,6}$/.match(version)
              next unless File.directory?(File.join(@@assets_dir, directory))
              # We've found something!
              found << File.join(directory, version)
            end
          end
        end
        # Return whatever we've found (which if nothing will be an empty array)
        found.sort
      end

      def has
        # Use query to find all the versions we have, then see if the version
        # requested exists in that last (first, making sure that it's valid)
        @reply.fail! "Invalid version (#{@version}) given" unless _validate(:full)
        query.include?(@version)
      end

      def add
        # First, check that the package name we've been given is useable
        @reply.fail! "Unable to determin package name from: #{@package}" unless /^([a-zA-Z0-9_\.\-]+)$/.match(@package)
        @version = @package.split(/\.([^.]*)$/).first.sub('_','/')
        @reply.fail! "#{@version} already installed" if has
        # Then create a temporary directory we can work within then fetch the
        # package we need to extract, finally extracting it as required.
        begin
          tmp = create_tmp
          package = get_package(tmp)
          extract(package, File.join(@@assets_dir, @version))
        # Catch anything which is a known stage failure within the deployment
        rescue DeployFail => e
          @reply.fail! "Deployment failed: #{e}"
        # Also catch any other form exception
        rescue => e
          @reply.fail! "Unknown failure: #{e}"
        end
        # If all has gone well, delete the temporary directory and report success back
        FileUtils.rm_rf(tmp)
        return "#{@version} deployed successfully"
      end

      def refresh
        # We'll keep this simple - remove the current contents if then re-add
        remove if has; add
      end

      def remove
        # Let's make sure that the version is correct and that it's available
        @reply.fail! "Invalid version (#{@version}) given" unless _validate(:full)
        @reply.fail! "#{@version} not installed" unless has
        # Remove everything in that directory, including the directory; we'll
        # wrap in a begin/rescue to catch any errors. If there are errors, just
        # report a fail and then the user can investigate or try again.
        begin
          FileUtils.rm_rf(@@assets_dir + '/' + @version)
          if has
            @reply.fail! "#{@version} not completly removed; may be left in incomplete state"
          else
            return "#{@version} removed successfully"
          end
        rescue => e
          @reply.fail! "Failed to remove @version: #{e}"
        end
      end

      private

      # Proviate a central method which will perform validation on the @version
      def _validate(type)
        case type
        when :simple
          /^[0-9]{5,6}$/.match(@version)
        when :full
          /^[a-z]{2}\/[0-9]{5,6}$/.match(@version)
        else
          false
        end
      end
    end

    # This is the Agent class and processes the above code based on the incoming
    # values we recieved from the MCollective API.
    class Deploy<RPC::Agent
      metadata :name        => "deploy",
               :description => "Agent to deploy our website, including Assets and Tomcat files.",
               :author      => "Jonathan Wright <jonathan@we7.com>",
               :license     => "Private",
               :version     => "1.0",
               :url         => "http://wiki.we7.com/mcollective/deploy",
               :timeout     => 180

      DeployPackage.valid_actions.each do |act|
        action act do
          # Get the details passed to us from the API
          application = request[:application]
          version     = request[:version]
          package     = request[:package]
          # Make a note of what we're trying to do in this run
          logger.debug "Processing #{application}/#{act}" + \
            (((not version.nil?) and (version.class == String)) ? "; :version => '#{version}'" : '') + \
            (((not package.nil?) and (package.class == String)) ? "; :package => '#{package[0,10]}...'" : '')
          # Make sure that there's a class for this application's deployment
          reply.fail! "Application #{application} not available" \
            unless Agent.const_defined?(application.capitalize) \
                && Agent.const_get(application.capitalize).class.is_a?(Class)
          # If a class exists, create an instance of it so we can work with it
          worker = Agent.const_get(application.capitalize).new(reply, logger, version, package)
          # Now make sure that the action requests has a method for it
          reply.fail! "Command not valid for target" \
            unless worker.do_validate(act)
          # And if it does, run it, with whatever is returned being the return
          # back to the client application for reporting
          reply[:output] = worker.send(act)
        end
      end
    end
  end
end
