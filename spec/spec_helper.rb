unless ENV["TRAVIS"]
  require 'simplecov'
  SimpleCov.start do
    add_group "lib", "lib"
    add_group "spec", "spec"
  end
end


require "rake-pipeline"
require "rake-pipeline/filters"

require "support/spec_helpers/file_utils"
require "support/spec_helpers/filters"
require "support/spec_helpers/input_helpers"
require "support/spec_helpers/memory_file_wrapper"

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
