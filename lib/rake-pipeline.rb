require "rake-pipeline/file_wrapper"
require "rake-pipeline/filter"

module Rake
  class Task
    def recursively_reenable(app)
      reenable
      prerequisites.each { |dep| app[dep].recursively_reenable(app) }
    end
  end

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

      def filter(filter_class, string=nil, &block)
        block ||= if string
          proc { string }
        else
          proc { |input| input }
        end

        filter = filter_class.new
        filter.output_name = block
        pipeline.add_filter(filter)
      end

      def output(root)
        pipeline.output_root = root
      end

      def tmpdir(root)
        pipeline.tmpdir = root
      end

      def rake_application(app)
        pipeline.rake_application = app
      end
    end

    attr_accessor :input_root, :output_root, :input_files, :tmpdir

    def initialize
      @filters = []
      @tmp_id = 0
      @tmpdir = "tmp"
    end

    def self.build(&block)
      pipeline = Pipeline.new
      DSL.evaluate(pipeline, &block)
      pipeline
    end

    def relative_input_files
      unless input_root && input_files
        raise Rake::Pipeline::Error, "You cannot get relative input files without " \
                                     "first providing input files and an input root"
      end

      expanded_root = Regexp.escape(File.expand_path(input_root))

      files = Dir[File.join(input_root, input_files)]
      files.map do |file|
        File.expand_path(file).sub(%r{^#{expanded_root}/}, '')
      end
    end

    def build
      current_input_root = File.expand_path(input_root)
      current_input_files = relative_input_files

      (@filters + [nil]).each_cons(2) do |filter, next_filter|
        filter.input_files = current_input_files

        # if filters are being reinvoked, they should keep their roots but
        # get updated with new files.
        unless filter.output_root
          filter.input_root = current_input_root

          if next_filter
            tmp = File.expand_path(File.join(self.tmpdir, generate_tmpname))
            current_input_root = filter.output_root = tmp
          else
            filter.output_root = File.expand_path(output_root)
          end
        end

        current_input_files = filter.output_files
      end
    end

    def rake_application
      @rake_application || Rake.application
    end

    def rake_application=(rake_application)
      @rake_application = rake_application
      @filters.each { |filter| filter.rake_application = rake_application }
      @rake_tasks = nil
    end

    def add_filters(*filters)
      filters.each { |filter| filter.rake_application = rake_application }
      @filters.concat(filters)
    end
    alias add_filter add_filters

    def invoke
      self.rake_application = Rake::Application.new unless @rake_application

      rake_tasks.each { |task| task.recursively_reenable(rake_application) }
      rake_tasks.each { |task| task.invoke }
    end

    def invoke_clean
      @rake_tasks = @rake_application = nil
      invoke
    end

    def rake_tasks
      @rake_tasks ||= begin
        tasks = nil
        build

        @filters.each do |filter|
          tasks = filter.rake_tasks
        end

        tasks
      end
    end

  private
    def generate_tmpname
      "rake-pipeline-tmp-#{@tmp_id += 1}"
    end
  end
end
