#!/usr/bin/env rake
require "bundler/gem_tasks"

task :docs => Dir["lib/**"] do
  sh "devbin/yard doc --readme README.yard --hide-void-return"
end

task :graph => :docs do
  sh "devbin/yard graph --dependencies | dot -Tpng -o arch.png"
end
