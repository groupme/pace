# -*- mode: ruby; encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "pace/version"

Gem::Specification.new do |s|
  s.name        = "pace"
  s.version     = Pace::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Dave Yeu", "Brandon Keene"]
  s.email       = ["daveyeu@gmail.com", "bkeene@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Resque-compatible job processing in an event loop}

  s.rubyforge_project = "pace"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "eventmachine", ">= 0.12.10"
  s.add_dependency "em-hiredis", ">= 0.1.0"
  s.add_dependency "uuid"
  s.add_dependency "systemu" # macaddr 1.2.0 breaks this

  s.add_development_dependency "rake"
  s.add_development_dependency "resque", "~> 1.17.1"
  s.add_development_dependency "rspec", "~> 2.6.0"
  s.add_development_dependency "i18n"
  s.add_development_dependency "hoptoad_notifier", "~> 2.4.11"
end
