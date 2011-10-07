require "rake-pipeline/file_wrapper"
require "rake-pipeline/filter"

module Rake
  class Pipeline
    class Error < StandardError
    end

    class DSL
      attr_reader :pipeline

      def self.evaluate(pipeline, &block)
        new(pipeline).instance_eval(&block)
      end

      def initialize(pipeline)
        @pipeline = pipeline
      end

      def input(root, files)
        pipeline.input_root = root
        pipeline.input_files = files
      end

      def filter(filter_class, &block)
        filter = filter_class.new
        filter.output_name = block
        pipeline.filters << filter
      end

      def output(root)
        pipeline.output_root = root
      end

      def tmpdir(root)
        pipeline.tmpdir = root
      end
    end

    attr_accessor :input_root
    attr_accessor :output_root
    attr_accessor :input_files
    attr_accessor :filters
    attr_accessor :tmpdir

    def initialize
      @filters = []
      @tmp_id = 0
      @tmpdir = "tmp"
    end

    def self.build(&block)
      pipeline = Pipeline.new
      DSL.evaluate(pipeline, &block)
      pipeline.rake_tasks
    end

    def relative_input_files
      unless input_root && input_files
        raise Rake::Pipeline::Error, "You cannot get relative input files without " \
                                     "first providing input files and an input root"
      end

      expanded_root = Regexp.escape(File.expand_path(input_root))

      input_files.map do |file|
        File.expand_path(file).sub(%r{^#{expanded_root}/}, '')
      end
    end

    def build
      current_input_root = File.expand_path(input_root)
      current_input_files = relative_input_files

      (filters + [nil]).each_cons(2) do |filter, next_filter|
        filter.input_root = current_input_root
        filter.input_files = current_input_files

        if next_filter
          tmp = File.expand_path(File.join(self.tmpdir, generate_tmpname))
          current_input_root = filter.output_root = tmp
        else
          filter.output_root = File.expand_path(output_root)
        end

        current_input_files = filter.output_files
      end
    end

    def rake_tasks
      build

      (filters + [nil]).each_cons(2) do |filter, next_filter|
        tasks = filter.rake_tasks
        return tasks unless next_filter
      end
    end

  private
    def generate_tmpname
      "rake-pipeline-tmp-#{@tmp_id += 1}"
    end
  end
end
