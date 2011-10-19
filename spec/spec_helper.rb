require 'simplecov'
SimpleCov.start do
  add_group "lib", "lib"
  add_group "spec", "spec"
end


require "rake-pipeline"
require "rake-pipeline/filters"

class Rake::Pipeline
  module SpecHelpers

    # TODO: OS agnostic modules
    module FileUtils
      def mkdir_p(dir)
        system "mkdir", "-p", dir
      end

      def touch(file)
        system "touch", file
      end

      def rm_rf(dir)
        system "rm", "-rf", dir
      end

      def touch_p(file)
        dir = File.dirname(file)
        mkdir_p dir
        touch file
      end

      def age_existing_files
        old_time = Time.now - 10
        Dir[File.join(tmp, "**/*.js")].each do |file|
          File.utime(old_time, old_time, file)
        end
      end
    end

    module Filters
      ConcatFilter = Rake::Pipeline::ConcatFilter

      class StripAssertsFilter < Rake::Pipeline::Filter
        def generate_output(inputs, output)
          inputs.each do |input|
            output.write input.read.gsub(%r{^\s*assert\(.*\)\s*;?\s*$}m, '')
          end
        end
      end
    end
  end
end

RSpec.configure do |config|
  original = Dir.pwd

  config.include Rake::Pipeline::SpecHelpers::FileUtils

  def tmp
    File.expand_path("../tmp", __FILE__)
  end

  config.before do
    rm_rf(tmp)
    mkdir_p(tmp)
    Dir.chdir(tmp)
  end

  config.after do
    Dir.chdir(original)
  end
end
