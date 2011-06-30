metadata :name        => "deploy",
         :description => "Agent to deploy our website, including assets and tomcat files.",
         :author      => "Jonathan Wright <jonathan@we7.com>",
         :license     => "Private",
         :version     => "1.0",
         :url         => "http://wiki.we7.com/mcollective/deploy",
         :timeout     => 180

['query'].each do |id|
  action "#{id}", :description => "Run #{id} against :application." do
    display :always

    input :application,
          :prompt      => "Which application will we run :#{id} against?",
          :description => "Target",
          :type        => :list,
          :optional    => false,
          :list        => ['we7','we7int','waif','assets','netlog']

    output :result,
           :description => "Result of the command.",
           :display_as => "Result"
  end
end

['has'].each do |id|
  action "#{id}", :description => "Run #{id} against :application." do
    display :always

    input :application,
          :prompt      => "Which application will we run :#{id} against?",
          :description => "Target",
          :type        => :list,
          :optional    => false,
          :list        => ['we7','we7int','waif','assets','netlog']

    input :version,
          :prompt      => "Which version do we need to work with?",
          :description => "Version",
          :type        => :string,
          :validation  => '^([a-z][a-zA-Z]\/[0-9]{5,6}|r?[0-9]{5,6}|[0-9]+(\.[0-9]+)*|trunk)$',
          :optional    => true,
          :maxlength   => 10

    output :result,
           :description => "Result of the command.",
           :display_as => "Result"
  end
end



['refresh'].each do |id|
  action "#{id}", :description => "Refresh the :package for :application." do
    display :always

    input :application,
          :prompt      => "Which application will we run :#{id} against?",
          :description => "Target",
          :type        => :list,
          :optional    => false,
          :list        => ['we7','we7int','waif','assets','netlog']

    input :package,
          :prompt      => "The details of the .torrent file for the package.",
          :description => "Package",
          :type        => :string,
          :validation  => '^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$',
          :optional    => false

    output :result,
           :description => "Result of the command.",
           :display_as => "Result"
  end
end

['add'].each do |id|
  action "#{id}", :description => "#{id.capitalize} the :package for :application." do
    display :always

    input :application,
          :prompt      => "Which application will we run :#{id} against?",
          :description => "Target",
          :type        => :list,
          :optional    => false,
          :list        => ['waif', 'assets', 'netlog']

    input :package,
          :prompt      => "The details of the .torrent file for the package.",
          :description => "Package",
          :type        => :string,
          :validation  => '^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$',
          :optional    => false

    output :result,
           :description => "Result of the command.",
           :display_as => "Result"
  end
end

['remove'].each do |id|
  action "#{id}", :description => "#{id.capitalize} :version from :application." do
    display :always

    input :application,
          :prompt      => "Which application will we run :#{id} against?",
          :description => "Target",
          :type        => :list,
          :optional    => false,
          :list        => ['waif', 'assets', 'netlog']

    input :version,
          :prompt      => "Which version do we need to work with?",
          :description => "Version",
          :type        => :string,
          :validation  => '^([a-z][a-zA-Z]\/[0-9]{5,6}|r?[0-9]{5,6}|[0-9]+(\.[0-9]+)*|trunk)$',
          :optional    => false,
          :maxlength   => 10

    output :result,
           :description => "Result of the command.",
           :display_as => "Result"
  end
end

['upgrade'].each do |id|
  action "#{id}", :description => "#{id.capitalize} the application with the contents of :package." do
    display :always

    input :application,
          :prompt      => "Which application will we run :#{id} against?",
          :description => "Target",
          :type        => :list,
          :optional    => false,
          :list        => ['we7', 'we7int']

    input :package,
          :prompt      => "Details of the .torrent file for the package to upgrade with.",
          :description => "Package",
          :type        => :string,
          :validation  => '^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$',
          :optional    => false,
          :maxlength   => 100

    output :result,
           :description => "Result of the command.",
           :display_as => "Result"
  end
end
