require 'rubygems'
require 'bundler/setup'

require 'mongoid'
require 'mongoid/tree'

require 'rspec'

Mongoid.configure do |config|
  config.master = Mongo::Connection.new.db('mongoid_tree_test')
  config.allow_dynamic_fields = false
end

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.mock_with :rspec
  config.after :each do
    Mongoid.master.collections.reject { |c| c.name =~ /^system\./ }.each(&:drop)
  end
end
