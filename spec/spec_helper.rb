require 'rubygems'
require 'bundler/setup'

require 'mongoid'
require 'mongoid/tree'

require 'rspec'

Mongoid.load!("#{File.dirname(__FILE__)}/support/mongoid.yml", :test)

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.mock_with :rspec
  config.after :each do
    Mongoid::Sessions.default.collections.reject { |c| c.name =~ /^system\./ }.each(&:drop)
  end
end
