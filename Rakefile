require 'rspec/core/rake_task'
require 'yard'

spec = Gem::Specification.load("mongoid-tree.gemspec")

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

YARD::Rake::YardocTask.new(:doc)

desc "Build the .gem file"
task :build do
  system "gem build #{spec.name}.gemspec"
end

desc "Push the .gem file to rubygems.org"
task :release => :build do
  system "gem push #{spec.name}-#{spec.version}.gem"
end

desc "Open an irb session"
task :console do
  sh "irb -rubygems -I lib -r ./spec/spec_helper.rb"
end