Gem::Specification.new do |s|
  s.name          = 'mongoid-tree'
  s.version       = '2.0.1'
  s.platform      = Gem::Platform::RUBY
  s.authors       = ['Benedikt Deicke']
  s.email         = ['benedikt@synatic.net']
  s.homepage      = 'https://github.com/benedikt/mongoid-tree'
  s.summary       = 'A tree structure for Mongoid documents'
  s.description   = 'A tree structure for Mongoid documents using the materialized path pattern'

  s.license       = 'MIT'

  s.files         = Dir.glob('{lib,spec}/**/*') + %w(LICENSE README.md Rakefile Gemfile .rspec)

  s.add_runtime_dependency('mongoid', ['< 7.0', '>= 4.0'])
  s.add_development_dependency('rake', ['>= 0.9.2'])
  s.add_development_dependency('rspec', ['~> 3.0'])
  s.add_development_dependency('yard', ['~> 0.8'])
end
