#!/usr/bin/env rake
require "bundler/gem_tasks"

directory "doc"

desc "generate documentation"
task :docs => Dir["lib/**"] do
  sh "devbin/yard doc --readme README.yard --hide-void-return"
end

desc "generate a dependency graph from the documentation"
task :graph => ["doc", :docs] do
  sh "devbin/yard graph --dependencies | dot -Tpng -o doc/arch.png"
end

desc "run the specs"
task :spec do
  sh "rspec -cfs spec"
end

task :default => :spec
