metadata :name        => "deploy",
         :description => "Agent to deploy our website, including assets and tomcat files.", 
         :author      => "Jonathan Wright <jonathan@we7.com>",
         :license     => "Private",
         :version     => "1.0.0",
         :url         => "http://wiki.we7.com/mcollective/deploy",
         :timeout     => 300

[:query => 'query', :has => 'has', :refresh => 'refresh'].each do |id,name|
  action "#{id}", :description => "Carry out the #{name} action against deployed applications" do
    display :always

    input :target,
          :prompt      => "Which target will we carry out the #{name} option against",
          :description => "Target",
          :type        => :list,
          :optional    => false,
          :list        => ['we7','we7int','waif','assets','netlog']

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

['add', 'remove'].each do |id|
  action "#{id}", :description => "Carry out the #{name} action against deployed applications" do
    display :always

    input :target,
          :prompt      => "Which target will we carry out the #{name} option against",
          :description => "Target",
          :type        => :list,
          :optional    => false,
          :list        => ['waif', 'assets', 'netlog']

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

['upgrade'].each do |id|
  action "#{id}", :description => "Carry out the #{name} action against deployed applications" do
    display :always

    input :target,
          :prompt      => "Which target will we carry out the #{name} option against",
          :description => "Target",
          :type        => :list,
          :optional    => false,
          :list        => ['we7', 'we7int']

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
