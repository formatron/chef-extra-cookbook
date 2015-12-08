%w(
  sensu
  ldap
).each do |hostname|
  hostsfile_entry '127.0.0.1' do
    hostname "#{hostname}.mydomain.com"
    action :append
  end
end

chef_server_version = '12.2.0-1'
username = 'test'
first_name = 'test'
last_name = 'user'
email = 'test@test.com'
password = 'password'
organization_short_name = 'org'
organization_full_name = 'organization'

node.default['formatron_chef_extra']['configuration'] = {
  'dsl' => {
    'global' => {
      'hosted_zone_name' => 'mydomain.com'
    }
  },
  'config' => {
    'logstash' => {
      'sub_domain' => 'logstash',
      'port' => '5044'
    },
    'sensu' => {
      'sub_domain' => 'sensu',
      'checks' => {
        'mycheck' => {
          'gem' => 'cpu',
          'attributes' => {
            'command' => 'check-cpu.rb',
            'standalone' => true,
            'subscribers' => ['default'],
            'interval' => 10,
            'handlers' => ['relay']
          }
        }
      },
      'gems' => {
        'cpu' => {
          'gem' => 'sensu-plugins-cpu-checks',
          'version' => '0.0.4'
        }
      },
      'rabbitmq' => {
        'vhost' => '/sensu',
        'user' => 'sensu',
        'password' => 'password'
      }
    },
    'ldap' => {
      'sub_domain' => 'ldap',
      'bind_dn' => 'cn=root',
      'bind_password' => 'password',
      'auth_name' => 'Crowd login',
      'uid' => 'uid',
      'search_base' => 'ou=myunit',
      'dn_suffix' => 'o=myorg',
      'first_name_attr' => 'givenName',
      'last_name_attr' => 'sn',
      'member_of_attr' => 'memberOf',
      'email_attr' => 'mail',
      'port' => 4000
    },
    'chef_server' => {
      'username' => username,
      'password' => password
    }
  }
}

bash 'install_chef' do
  code <<-EOH.gsub(/^ {4}/, '')
    #!/bin/bash -v

    set -e

    export HOME=/root

    apt-get -y update
    apt-get -y install wget ntp cron git libfreetype6 libpng3 python-pip
    pip install awscli

    mkdir -p /etc/opscode/chef-server.rb.d

    cat << EOF > /etc/opscode/chef-server.rb
    Dir[File.dirname(__FILE__) + '/chef-server.rb.d/*.rb'].each do |file|
      self.instance_eval File.read(file), file
    end
    EOF

    wget -O /tmp/chef-server-core.deb https://web-dl.packagecloud.io/chef/stable/packages/ubuntu/trusty/chef-server-core_#{chef_server_version}_amd64.deb
    dpkg -i /tmp/chef-server-core.deb

    chef-server-ctl reconfigure >> /var/log/chef-install.log
    chef-server-ctl user-create #{username} #{first_name} #{last_name} #{email} #{password} --filename $HOME/user.pem >> /var/log/chef-install.log
    chef-server-ctl org-create #{organization_short_name} "#{organization_full_name}" --association_user #{username} --filename $HOME/organization.pem >> /var/log/chef-install.log

    chef-server-ctl install opscode-manage >> /var/log/chef-install.log
    chef-server-ctl reconfigure >> /var/log/chef-install.log
    opscode-manage-ctl reconfigure >> /var/log/chef-install.log

    chef-server-ctl install opscode-push-jobs-server >> /var/log/chef-install.log
    chef-server-ctl reconfigure >> /var/log/chef-install.log
    opscode-push-jobs-server-ctl reconfigure >> /var/log/chef-install.log

    chef-server-ctl install opscode-reporting >> /var/log/chef-install.log
    chef-server-ctl reconfigure >> /var/log/chef-install.log
    opscode-reporting-ctl reconfigure >> /var/log/chef-install.log
  EOH
  not_if Dir.exist?('/etc/opscode/chef-server.rb.d')
end

node.default['formatron_sensu']['client']['subscriptions'] = ['default']

include_recipe 'formatron_chef_extra::default'
