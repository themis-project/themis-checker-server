lib = File.expand_path '../lib', __FILE__
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'themis/checker/version'

Gem::Specification.new do |s|
    s.name = 'themis-checker'
    s.version = Themis::Checker::VERSION
    s.date = '2015-07-13'
    s.summary = 'Themis Checker'
    s.description = 'Checker interface for Themis contest checking system'
    s.authors = ['Alexander Pyatkin']
    s.email = 'asp@thexyz.net'
    s.files = [
        'lib/themis/checker.rb',
        'lib/themis/checker/version.rb',
        'lib/themis/checker/result.rb',
        'lib/themis/checker/server.rb'
    ]
    s.homepage = 'http://github.com/aspyatkin/themis-checker-rb'
    s.license = 'MIT'

    s.required_ruby_version = '>= 2.0'

    s.add_dependency 'beaneater'
    s.add_dependency 'ruby-enum'

    s.add_development_dependency 'bundler'
    s.add_development_dependency 'rake'
end
