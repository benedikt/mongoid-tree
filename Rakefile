require 'rspec/core/rake_task'
require 'rdoc/task'

spec = Gem::Specification.load("mongoid-tree.gemspec")

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

Rake::RDocTask.new do |rdoc|
  rdoc.generator = 'hanna'
  rdoc.rdoc_dir = 'doc'
  rdoc.title = "#{spec.name} #{spec.version}"
  rdoc.options += spec.rdoc_options
  rdoc.rdoc_files.include(spec.extra_rdoc_files)
  rdoc.rdoc_files.include('lib/**/*.rb')
end

desc "Build the .gem file"
task :build do
  system "gem build #{spec.name}.gemspec"
end

desc "Push the .gem file to rubygems.org"
task :release => :build do
  system "gem push #{spec.name}-#{spec.version}.gem"
end
