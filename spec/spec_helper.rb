require 'rubygems'
require 'bundler/setup'

require 'mongoid'
require 'mongoid/tree'

require 'rspec'

Mongoid.configure do |config|
  config.connect_to('mongoid_tree_test')
end

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  config.mock_with :rspec
  config.after(:each) { Mongoid.purge! }
end
