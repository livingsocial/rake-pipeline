require "rake-pipeline/file_wrapper"
require "rake-pipeline/filter"
require "rake-pipeline/filters"
require "rake-pipeline/dsl"

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

    class EncodingError < Error
    end

    attr_accessor :input_glob
    attr_reader   :input_root, :output_root, :tmpdir

    def initialize
      @filters = []
      @tmp_id = 0
      @tmpdir = "tmp"
      @pipelines = []
    end

    def self.build(&block)
      pipeline = Pipeline.new
      DSL.evaluate(pipeline, &block) if block
      pipeline
    end

    @tmp_id = 0

    def self.generate_tmpname
      "rake-pipeline-tmp-#{@tmp_id += 1}"
    end

    def build(&block)
      pipeline = self.class.build(&block)
      pipeline.input_root = input_root
      pipeline.output_root = output_root
      pipeline.tmpdir = tmpdir
      @pipelines << pipeline
      pipeline
    end

    def input_root=(root)
      @input_root = root
      @pipelines.each { |pipeline| pipeline.input_root = root }
    end

    def output_root=(root)
      @output_root = root
      @pipelines.each { |pipeline| pipeline.output_root = root }
    end

    def tmpdir=(dir)
      @tmpdir = dir
      @pipelines.each { |pipeline| pipeline.tmpdir = dir }
    end

    def input_files
      unless input_root && input_glob
        raise Rake::Pipeline::Error, "You cannot get relative input files without " \
                                     "first providing input files and an input root"
      end

      expanded_root = File.expand_path(input_root)
      files = Dir[File.join(expanded_root, input_glob)]

      files.map do |file|
        relative_path = file.sub(%r{^#{Regexp.escape(expanded_root)}/}, '')
        FileWrapper.new(expanded_root, relative_path)
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

    def invoke(invoke_children=true)
      self.rake_application = Rake::Application.new unless @rake_application

      rake_tasks.each { |task| task.recursively_reenable(rake_application) }
      rake_tasks.each { |task| task.invoke }

      @pipelines.each { |pipeline| pipeline.invoke } if invoke_children
    end

    def invoke_clean
      @rake_tasks = @rake_application = nil

      invoke(false)
      @pipelines.each { |pipeline| pipeline.invoke_clean }
    end

    def rake_tasks
      @rake_tasks ||= begin
        tasks = []
        process_filters

        @filters.each do |filter|
          tasks = filter.rake_tasks
        end

        tasks
      end
    end

  private
    def process_filters
      return if @filters.empty?

      current_input_files = input_files

      (@filters + [nil]).each_cons(2) do |filter, next_filter|
        filter.input_files = current_input_files

        # if filters are being reinvoked, they should keep their roots but
        # get updated with new files.
        unless filter.output_root
          if next_filter
            tmp = File.expand_path(File.join(self.tmpdir, self.class.generate_tmpname))
            filter.output_root = tmp
          else
            filter.output_root = File.expand_path(output_root)
          end
        end

        current_input_files = filter.output_files
      end
    end
  end
end
