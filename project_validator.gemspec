# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "version"

Gem::Specification.new do |s|
  s.name        = "project_validator"
  s.version     = ProjectValidator::VERSION
  s.authors     = ["Adrian Toman"]
  s.email       = ["adrian.toman@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{MS Infratructure}
  s.description = %q{MS Infratructure}

  s.rubyforge_project = "project_validator"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_dependency "gooddata"
  s.add_dependency "json"
  s.add_dependency "archiver"
  s.add_dependency "gli"
  s.add_dependency "chronic"
  s.add_dependency "fastercsv"
  s.add_dependency "logger"

end

