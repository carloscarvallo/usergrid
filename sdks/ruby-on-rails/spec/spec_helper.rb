require 'simplecov'
require 'test/unit'
require 'rspec'
require 'yaml'
require 'securerandom'
require_relative '../lib/usergrid_ironhorse'

ENV["RAILS_ENV"] ||= 'test'
Dir[Pathname.new(File.dirname(__FILE__)).join("support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.mock_with :rspec
  config.expect_with :stdlib
  config.expect_with :rspec
end

LOG = Logger.new(STDOUT)
RestClient.log=LOG

SimpleCov.at_exit do
  SimpleCov.result.format!
  #index = File.join(SimpleCov.coverage_path, 'index.html')
  #`open #{index}` if File.exists?(index)
end
SimpleCov.start


SPEC_SETTINGS = YAML::load_file(File.join File.dirname(__FILE__), 'spec_settings.yaml')

def login_management
  management = Usergrid::Resource.new(SPEC_SETTINGS[:api_url]).management
  management.login SPEC_SETTINGS[:organization][:username], SPEC_SETTINGS[:organization][:password]
  management
end

# ensure we are correctly setup (management login & organization)
management = login_management

begin
  management.create_organization(SPEC_SETTINGS[:organization][:name],
                                 SPEC_SETTINGS[:organization][:username],
                                 SPEC_SETTINGS[:organization][:username],
                                 "#{SPEC_SETTINGS[:organization][:username]}@email.com",
                                 SPEC_SETTINGS[:organization][:password])
  LOG.info "created organization with user #{SPEC_SETTINGS[:organization][:username]}@email.com"
rescue
  if MultiJson.load($!.response)['error'] == "duplicate_unique_property_exists"
    LOG.debug "test organization exists"
  else
    raise $!
  end
end

def create_random_application
  management = login_management
  organization = management.organization SPEC_SETTINGS[:organization][:name]
  app_name = "_test_app_#{SecureRandom.hex}"
  organization.create_application app_name
  management.application SPEC_SETTINGS[:organization][:name], app_name
end

def delete_application(application)
  management = login_management
  application.auth_token = management.auth_token
  application.delete rescue nil  # not implemented on server yet
end

def create_random_user(application, login=false)
  random = SecureRandom.hex
  user_hash = {username: "username_#{random}",
               password: random,
               email:    "#{random}@email.com",
               name:     "#{random} name" }
  entity = application['users'].post(user_hash).entity
  application.login user_hash[:username], user_hash[:password] if login
  entity
end
