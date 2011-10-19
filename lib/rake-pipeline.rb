require "rake-pipeline/file_wrapper"
require "rake-pipeline/filter"
require "rake-pipeline/filters"
require "rake-pipeline/dsl"
require "rake-pipeline/matcher"

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
    attr_reader   :input_root, :output_root, :output_files, :tmpdir, :rake_tasks

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

    def generate_tmpdir
      File.join(tmpdir, self.class.generate_tmpname)
    end

    def build(&block)
      pipeline = self.class.build(&block)
      pipeline.input_root = input_root
      pipeline.output_root = File.expand_path(output_root)
      pipeline.tmpdir = tmpdir
      @pipelines << pipeline
      pipeline
    end

    def input_root=(root)
      @input_root = File.expand_path(root)
      @pipelines.each { |pipeline| pipeline.input_root = root }
    end

    def output_root=(root)
      @output_root = File.expand_path(root)
      @pipelines.each { |pipeline| pipeline.output_root = root }
    end

    def tmpdir=(dir)
      @tmpdir = File.expand_path(dir)
      @pipelines.each { |pipeline| pipeline.tmpdir = dir }
    end

    def input_files
      return @input_files if @input_files

      assert_input_provided

      expanded_root = File.expand_path(input_root)
      files = Dir[File.join(expanded_root, input_glob)]

      files.map do |file|
        relative_path = file.sub(%r{^#{Regexp.escape(expanded_root)}/}, '')
        FileWrapper.new(expanded_root, relative_path)
      end
    end

    # for Pipelines, this is every file, but it may be overridden
    # by subclasses
    alias eligible_input_files input_files

    def input_files=(files)
      @input_files = files
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

      setup

      @rake_tasks.each { |task| task.recursively_reenable(rake_application) }
      @rake_tasks.each { |task| task.invoke }

      @pipelines.each { |pipeline| pipeline.invoke } if invoke_children
    end

    def invoke_clean
      @rake_tasks = @rake_application = nil

      invoke(false)
      @pipelines.each { |pipeline| pipeline.invoke_clean }
    end

    def setup
      setup_filters
      generate_rake_tasks
    end

    def output_files
      @filters.last.output_files unless @filters.empty?
    end

  protected
    def setup_filters
      last = @filters.last

      @filters.inject(input_files) do |current_inputs, filter|
        filter.input_files = current_inputs

        # if filters are being reinvoked, they should keep their roots but
        # get updated with new files.
        filter.output_root ||= begin
          output = if filter == last
            output_root
          else
            generate_tmpdir
          end

          File.expand_path(output)
        end

        filter.setup_filters if filter.respond_to?(:setup_filters)

        filter.output_files
      end
    end

    def generate_rake_tasks
      @rake_tasks ||= begin
        tasks = []

        @filters.each do |filter|
          # TODO: Don't generate rake tasks if we aren't
          # creating a new Rake::Application
          tasks = filter.generate_rake_tasks
        end

        tasks
      end
    end

    def assert_input_provided
      if !input_root || !input_glob
        raise Rake::Pipeline::Error, "You cannot get input files without " \
                                     "first providing input files and an input root"
      end
    end
  end
end
