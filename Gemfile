source 'https://rubygems.org'

gemspec

unless ENV['CI']
  gem 'guard-rspec', '>= 0.6.0'
  gem 'ruby_gntp',   '>= 0.3.4'
  gem 'rb-fsevent' if RUBY_PLATFORM =~ /darwin/
end

platforms :rbx do
  gem 'rubysl-rake', '~> 2.0'
end
