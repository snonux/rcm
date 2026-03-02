Gem::Specification.new do |s|
  s.required_ruby_version = '>= 3.3.0'
  s.name                  = 'rcm'
  s.version               = '0.1.2'
  s.licenses              = ['BSD3']
  s.summary               = 'Ruby Configuration Management system'
  s.description           = 'To configure my stuff'
  s.authors               = ['Paul Buetow']
  s.email                 = 'rcm@dev.buetow.org'
  s.files                 = Dir['lib/**/*.rb']
  s.executables           = ['rcm']
  s.homepage              = 'https://codeberg.org/snonux/rcm'
  s.metadata              = { 'source_code_uri' => 'https://codeberg.org/snonux/rcm' }

  s.add_runtime_dependency 'erb'
  s.add_runtime_dependency 'toml', '~> 0.3'
end
