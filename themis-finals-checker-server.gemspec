::Gem::Specification.new do |s|
  s.name = 'themis-finals-checker-server'
  s.version = '4.0.0'
  s.date = '2016-07-17'
  s.summary = 'Themis::Finals::Checker::Server'
  s.description = 'Service checker base class for Themis contest checking system'
  s.authors = ['Alexander Pyatkin']
  s.email = 'aspyatkin@gmail.com'
  s.files = ['lib/themis/finals/checker/server.rb']
  s.homepage = 'http://github.com/aspyatkin/themis-finals-checker-server'
  s.license = 'MIT'

  s.required_ruby_version = '>= 2.0'

  s.add_dependency 'beaneater'
  s.add_dependency 'json'
  s.add_dependency 'themis-finals-checker-result', '~> 2.0.0'
  s.add_dependency 'time_difference', '~> 0.4.2'
  s.add_dependency 'sentry-raven', '~> 1.0.0'

  s.add_development_dependency 'bundler'
  s.add_development_dependency 'rake'
end
