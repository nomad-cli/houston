# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'houston/version'

Gem::Specification.new do |s|
  s.name        = 'houston'
  s.authors     = ['Mattt Thompson']
  s.email       = 'm@mattt.me'
  s.license     = 'MIT'
  s.homepage    = 'http://nomad-cli.com'
  s.version     = Houston::VERSION
  s.platform    = Gem::Platform::RUBY
  s.summary     = 'Send Apple Push Notifications'
  s.description = 'Houston is a simple gem for sending Apple Push Notifications. Pass your credentials, construct your message, and send it.'

  s.add_dependency 'commander', '~> 4.4'
  s.add_dependency 'json'

  s.add_development_dependency 'rspec', '~> 3.5'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'simplecov'

  s.files         = Dir['./**/*'].reject { |file| file =~ /\.\/(bin|log|pkg|script|spec|test|vendor)/ }
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ['lib']
end
