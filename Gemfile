source 'https://rubygems.org'

gemspec

case version = ENV['MONGOID_VERSION'] || '~> 7.0'
when 'HEAD' then gem 'mongoid', github: 'mongodb/mongoid'
when /8/    then gem 'mongoid', '~> 8.0'
when /7/    then gem 'mongoid', '~> 7.0'
when /6/    then gem 'mongoid', '~> 6.0'
when /5/    then gem 'mongoid', '~> 5.0'
when /4/    then gem 'mongoid', '~> 4.0'
else             gem 'mongoid', version
end

unless ENV['CI']
  gem 'guard-rspec', '>= 0.6.0'
  gem 'ruby_gntp',   '>= 0.3.4'
  gem 'rb-fsevent' if RUBY_PLATFORM =~ /darwin/
end
