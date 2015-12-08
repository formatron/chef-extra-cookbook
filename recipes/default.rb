configuration = node['formatron_chef_extra']['configuration']

hosted_zone_name = configuration['dsl']['global']['hosted_zone_name']
ldap_config = configuration['config']['ldap']
ldap_sub_domain = ldap_config['sub_domain']
ldap_host = "#{ldap_sub_domain}.#{hosted_zone_name}"
ldap_port = ldap_config['port']
ldap_search_base = ldap_config['search_base']
ldap_bind_dn = ldap_config['bind_dn']
ldap_bind_password = ldap_config['bind_password']
ldap_uid = ldap_config['uid']
ldap_auth_name = ldap_config['auth_name']
ldap_dn_suffix = ldap_config['dn_suffix']

node.default['formatron_common']['configuration'] = configuration
include_recipe 'formatron_common::default'

template '/etc/opscode/chef-server.rb.d/ldap.rb' do
  variables(
    base_dn: "#{ldap_search_base},#{ldap_dn_suffix}",
    bind_dn: "#{ldap_bind_dn},#{ldap_dn_suffix}",
    bind_password: ldap_bind_password,
    host: ldap_host,
    login_attribute: ldap_uid,
    port: ldap_port,
    system_adjective: ldap_auth_name
  )
  notifies :run, 'bash[reconfigure_chef]', :delayed
end

bash 'reconfigure_chef' do
  code <<-EOH.gsub(/^ {4}/, '')
    set -e
    chef-server-ctl reconfigure
    opscode-manage-ctl reconfigure
  EOH
  action :nothing
end
