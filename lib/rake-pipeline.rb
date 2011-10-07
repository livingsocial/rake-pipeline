require "rake-pipeline/file_wrapper"
require "rake-pipeline/filter"

module Rake
  class Pipeline
    attr_accessor :root
    attr_accessor :glob
  end
end
