module MCollective
  module Agent
    class Deploy<RPC::Agent
      metadata :name        => "deploy",
               :description => "Agent to deploy our website, including Assets and Tomcat files.",
               :author      => "Jonathan Wright <jonathan@we7.com>",
               :license     => "Private",
               :version     => "1.0.0",
               :url         => "http://wiki.we7.com/mcollective/deploy",
               :timeout     => 300

      # Define the actions (i.e. packages) which deploy script will work with. In
      # general they all have the same sets of arguments some slight variations,
      # so all commands will go to a central method which will validate the
      # options and arguments and then from there launch the required command
      ['waif', 'assets', 'netlog', 'we7', 'we7int'].each do |package|
        action act do
          do_validate(package)
        end
      end

      private # ----------------------------------------------------------------

      ## do_validate(package)
      # Validator for this Agent; all the requests generally have the same
      # validation requirements, so this function will validate all the data as
      # required and then pass off the request onto the correct function.
      def do_validate(package)
        # Validate the input data according to our DDL (:command will be
        # validated later based on package). Also, we'll only validate :version
        # if we're not running a query (and silently ignore it if its provided)
        validate :command, String
        validate :version, String
        validate :version, /^(r[0-9]+|[0-9\.]+|trunk)$/ unless request[:command] = 'query'

        # Extract the variables we need
        command = request[:command]
        version = request[:version]

        case package
        when 'waif', 'assets', 'netlog'
          # Validate our command actions before we continue
          reply.fail! "#{package} #{command}: Invalid request to deploy.", 4 \
            unless ['query', 'has', 'add', 'refresh', 'remove'].search(command)

        when 'we7', 'we7int'
          # Validate our command actions before we continue
          reply.fail! "#{package} #{command}: Invalid request to deploy.", 4 \
            unless ['query', 'has', 'upgrade', 'refresh'].search(command)

        else
          # Configure catch-all for anything we don't recognise
          reply.fail! "#{package} not managed by depoly.", 2
        end

        case command
        when 'query'
          reply[:result] = query(package)

        when 'has'
          reply[:result] = (query(package).search(version) ? 'Found' : 'Not Found')

      end

      def query(package)
        # Create an empty array, into which we'll add all the versions we find
        versions = []

        # Different packages are configured in different locations, so configure
        # where we need to search to find out which versions are installed
        search_path = \
          (package == 'waif'   ? '/var/www/virtual/waif.we7c.net' : \
           package == 'netlog' ? '/var/www/virtual/netlog.devices.we7.com' : \
           package == 'assets' ? '/var/www/tomcat/assets' : nil)

        # Sanity check
        reply.fail! "Unable to set search path for #{package}." unless search_path

        # First, look for the release/ directory, and then find all the
        # directories under that; they'll be official releases
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

        # For the assets system, we have a different structure, based around the
        # names of the release and the version of the site we're using
        Dir.entries(search_path).sort.each do |entry|
          # Skip any special links
          next if entry =~ /^\.+$/

          if entry =~ /^[a-z][PT]$/
            # These entries are for trunk and pending; add them but try and find
            # out which revision they're using at the same time
            type = (entry[1,1] == 'T' ? 'trunk' : 'pending')
            begin
              if File.exists(search_path + '/' + entry + '/.revision')
                File.open(search_path + '/' + entry + '/.revision') do |file|
                  versions.push(type + ' (' + file.gets.chomp + ')')
                end
              else
                versions.push(type)
              end
            rescue
              versions.push(type)
            end
          else
            versions.push(entry)
          end
        end

        # Having completed all the tests, let's check we've found something and
        # then report back accordingly; failing if there's nothing there
        reply.fail! "No versions of #{package} found!" if versions.empty?
        reply[:result] = versions.join(', ')
      end

      def do_remove(package, version)

      end

      def do_add(package, version)

      end

      def do_upgrade(package, version)

      end

      def do_refresh(package, version)

      end
    end
  end
end
