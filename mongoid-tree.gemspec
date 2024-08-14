Gem::Specification.new do |s|
  s.name          = 'mongoid-tree'
  s.version       = '2.3.0'
  s.platform      = Gem::Platform::RUBY
  s.authors       = ['Benedikt Deicke']
  s.email         = ['benedikt@synatic.net']
  s.homepage      = 'https://github.com/benedikt/mongoid-tree'
  s.summary       = 'A tree structure for Mongoid documents'
  s.description   = 'A tree structure for Mongoid documents using the materialized path pattern'

  s.license       = 'MIT'

  s.files         = Dir.glob('{lib,spec}/**/*') + %w(LICENSE README.md Rakefile Gemfile)

  s.add_runtime_dependency('mongoid', ['>= 4.0', '< 10'])
  s.add_development_dependency('mongoid-compatibility')
  s.add_development_dependency('rake', ['>= 0.9.2'])
  s.add_development_dependency('rspec', ['~> 3.0'])
  s.add_development_dependency('yard', ['>= 0.9.20'])
end
