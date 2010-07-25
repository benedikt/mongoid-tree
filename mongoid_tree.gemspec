Gem::Specification.new do |s|
  s.name          = 'mongoid_tree'
  s.version       = '0.1'
  s.platform      = Gem::Platform::RUBY
  s.authors       = ['Benedikt Deicke']
  s.email         = ['benedikt@synatic.net']
  s.homepage      = 'http://github.com/benedikt/mongoid_tree'
  s.summary       = 'A tree structure for Mongoid documents'
  s.description   = 'A tree structure for Mongoid documents using the materialized path pattern'
 
  s.has_rdoc      = true
  s.rdoc_options  = ['--main', 'README.rdoc', '--charset=UTF-8']
  s.extra_rdoc_files = ['README.rdoc', 'LICENSE']
 
  s.files         = Dir.glob('{lib,spec}/**/*') + %w(LICENSE README.rdoc Rakefile Gemfile .rspec)
  
  s.add_runtime_dependency('mongoid', ['>= 2.0.0.beta9'])
  s.add_development_dependency('rspec', ['>= 2.0.0.beta.18'])
  s.add_development_dependency('autotest', ['>= 4.3.2'])
end