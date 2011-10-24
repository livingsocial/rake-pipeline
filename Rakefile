#!/usr/bin/env rake
require "bundler/gem_tasks"

directory "doc"

task :docs => Dir["lib/**"] do
  sh "devbin/yard doc --readme README.yard --hide-void-return"
end

task :graph => ["doc", :docs] do
  sh "devbin/yard graph --dependencies | dot -Tpng -o doc/arch.png"
end
