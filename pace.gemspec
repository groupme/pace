# -*- mode: ruby; encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "pace/version"

Gem::Specification.new do |s|
  s.name        = "pace"
  s.version     = Pace::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Dave Yeu"]
  s.email       = ["daveyeu@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Resque-compatible job processing in an event loop}

  s.rubyforge_project = "pace"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "em-redis", ">= 0.3.0"
  s.add_dependency "uuid"

  s.add_development_dependency "resque", "~> 1.17.1"
  s.add_development_dependency "rspec",  "~> 2.6.0"
end
