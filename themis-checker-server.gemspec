Gem::Specification.new do |s|
    s.name = 'themis-checker-server'
    s.version = '1.0.0'
    s.date = '2015-07-15'
    s.summary = 'Themis::Checker::Server'
    s.description = 'Service checker base class for Themis contest checking system'
    s.authors = ['Alexander Pyatkin']
    s.email = 'asp@thexyz.net'
    s.files = ['lib/themis/checker/server.rb']
    s.homepage = 'http://github.com/aspyatkin/themis-checker-server'
    s.license = 'MIT'

    s.required_ruby_version = '>= 2.0'

    s.add_dependency 'beaneater'
    s.add_dependency 'json'
    s.add_dependency 'themis-checker-result'

    s.add_development_dependency 'bundler'
    s.add_development_dependency 'rake'
end
