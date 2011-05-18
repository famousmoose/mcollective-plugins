metadata :name        => "deploy",
         :description => "Agent to deploy our website, including assets and tomcat files.", 
         :author      => "Jonathan Wright <jonathan@we7.com>",
         :license     => "Private",
         :version     => "1.0.0",
         :url         => "http://wiki.we7.com/mcollective/deploy",
         :timeout     => 300

[:waif => 'WAIF', :assets => 'Assets', :netlog => 'Netlog'].each do |id,name|
  action "#{id}", :description => "Deploy and managed the #{name} application" do
    display :always

    input :command,
          :prompt      => "What operation we need to run against #{name}",
          :description => "Command",
          :type        => :list,
          :optional    => false,
          :list        => ['query', 'has', 'add', 'refresh', 'remove']

    input :version,
          :prompt      => "Which version do we need to work with?",
          :description => "Version",
          :type        => :string,
          :validation  => '^(r[0-9]+|[0-9]+(\.[0-9]+)*|trunk)$',
          :optional    => true,
          :maxlength   => 10

    output :result,
           :description => "Result of the command requested for #{name}",
           :display_as => "Result"
  end
end

['we7', 'we7int'].each do |id|
  action "#{id}", :description => "Deploy and managed the #{id} application" do
    display :always

    input :command,
          :prompt      => "What operation we need to run against #{id}",
          :description => "Command",
          :type        => :list,
          :optional    => false,
          :list        => ['query', 'has', 'upgrade', 'refresh']

    input :version,
          :prompt      => "Which version do we need to work with?",
          :description => "Version",
          :type        => :string,
          :validation  => '^(r[0-9]+|[0-9]+(\.[0-9]+)*|trunk)$',
          :optional    => true,
          :maxlength   => 10

    output :result,
           :description => "Result of the command requested for #{id}",
           :display_as => "Result"
  end
end
