require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'yard'

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

YARD::Rake::YardocTask.new(:doc)

desc "Open an irb session"
task :console do
  sh "irb -rubygems -I lib -r ./spec/spec_helper.rb"
end
