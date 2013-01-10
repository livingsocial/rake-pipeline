# -*- encoding: utf-8 -*-
require File.expand_path('../lib/rake-pipeline/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Yehuda Katz", "Tom Dale"]
  gem.email         = ["wycats@gmail.com"]
  gem.description   = "Simple Asset Management"
  gem.summary       = "Simple Asset Management"
  gem.homepage      = ""

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "rake-pipeline"
  gem.require_paths = ["lib"]
  gem.version       = Rake::Pipeline::VERSION

  gem.add_dependency "rake", "~> 10.0.0"
  gem.add_dependency "thor"
  gem.add_dependency "json"

  gem.add_development_dependency "rspec"
  gem.add_development_dependency "rack-test"
end
