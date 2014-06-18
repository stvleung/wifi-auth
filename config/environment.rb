# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Initialize the Rails application.
Rails.application.initialize!

# Enable SSL on production
#SslRequirement.ssl_all = true if Rails.env.production?

# Load up configuration YAML
c = YAML::load(File.open("#{Rails.root}/config/config.yml"))

# LDAP
$ldap_basedn = c[Rails.env]['ldap']['basedn']
$ldap_usersdn = c[Rails.env]['ldap']['usersdn']
$ldap_groupdn = c[Rails.env]['ldap']['groupdn']
$ldap_host = c[Rails.env]['ldap']['host']
$ldap_port = c[Rails.env]['ldap']['port']
$ldap_username = c[Rails.env]['ldap']['username']
$ldap_password = c[Rails.env]['ldap']['password']

# Router configuration
$router = c[Rails.env]['router']

# Auth configuration
$auth = c[Rails.env]['auth']
