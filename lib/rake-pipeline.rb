require "rake-pipeline/file_wrapper"
require "rake-pipeline/filter"
require "rake-pipeline/filters"
require "rake-pipeline/dsl"
require "rake-pipeline/matcher"

module Rake
  # Override Rake::Task to support recursively re-enabling
  # a task and its dependencies.
  class Task

    # @param [Rake::Application] app a Rake Application
    # @return [void]
    def recursively_reenable(app)
      reenable

      prerequisites.each do |dep|
        app[dep].recursively_reenable(app)
      end
    end
  end

  # A Pipeline is responsible for taking a directory of input
  # files, applying a number of filters to the inputs, and
  # outputting them into an output directory.
  class Pipeline
    class Error < StandardError
    end

    class EncodingError < Error
    end

    # @return [String] a glob representing the input files
    attr_accessor :input_glob

    # @return [String] the directory path for the input files.
    attr_reader   :input_root

    # @return [String] the directory path for the output files.
    attr_reader   :output_root

    # @return [String] the directory path for temporary files.
    attr_reader   :tmpdir

    # @return [Array] an Array of Rake::Task objects. This
    #   property is populated by the #generate_rake_tasks
    #   method.
    attr_reader   :rake_tasks

    # @return [String] a list of files that will be outputted
    #   to the output directory when the pipeline is invoked
    attr_reader   :output_files

    attr_writer :input_files

    def initialize
      @filters = []
      @tmp_id = 0
      @tmpdir = "tmp"
      @pipelines = []
    end

    # Build a new pipeline taking a block. The block will
    # be evaluated by the Rake::Pipeline::DSL class.
    #
    # @see Rake::Pipeline::Filter
    #
    # @example
    #   Rake::Pipeline.build do
    #     input "app/assets"
    #     output "public"
    #
    #     filter Rake::Pipeline::ConcatFilter, "app.js"
    #   end
    #
    # @return [Rake::Pipeline] the newly configured pipeline
    def self.build(&block)
      pipeline = Pipeline.new
      DSL.evaluate(pipeline, &block) if block
      pipeline
    end

    @tmp_id = 0

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

    # If you specify a glob for #input_glob, this method will
    # calculate the input files for the directory. If you supply
    # input_files directly, this method will simply return the
    # input_files you supplied.
    #
    # @return [Array<FileWrapper>] An Array of file wrappers
    #   that represent the inputs for the current pipeline.
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

    # @return [Rake::Application] The Rake::Application to install
    #   rake tasks onto. Defaults to Rake.application
    def rake_application
      @rake_application || Rake.application
    end

    # Set the rake_application on the pipeline and apply it to filters.
    #
    # @return [void]
    def rake_application=(rake_application)
      @rake_application = rake_application
      @filters.each { |filter| filter.rake_application = rake_application }
      @rake_tasks = nil
    end

    # Add one or more filters to the current pipeline.
    #
    # @param [Array<Filter>] filters a list of filters
    # @return [void]
    def add_filters(*filters)
      filters.each { |filter| filter.rake_application = rake_application }
      @filters.concat(filters)
    end
    alias add_filter add_filters

    # Invoke the pipeline, processing the inputs into the output. If
    # the pipeline has already been invoked, reinvoking will not
    # pick up new input files added to the file system.
    #
    # @return [void]
    def invoke(invoke_children=true)
      self.rake_application = Rake::Application.new unless @rake_application

      setup

      @rake_tasks.each { |task| task.recursively_reenable(rake_application) }
      @rake_tasks.each { |task| task.invoke }

      @pipelines.each { |pipeline| pipeline.invoke } if invoke_children
    end

    # Pick up any new files added to the inputs and process them through
    # the filters. Then call #invoke.
    #
    # @return [void]
    def invoke_clean
      @rake_tasks = @rake_application = nil

      invoke(false)
      @pipelines.each { |pipeline| pipeline.invoke_clean }
    end

    # Set up the filters and generate rake tasks. In general, this method
    # is called by invoke.
    #
    # @return [void]
    # @api private
    def setup
      setup_filters
      generate_rake_tasks
    end

    def output_files
      @filters.last.output_files unless @filters.empty?
    end

  protected
    # Generate a new temporary directory name.
    #
    # @return [String] a unique temporary directory name
    def self.generate_tmpname
      "rake-pipeline-tmp-#{@tmp_id += 1}"
    end

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

    def generate_tmpdir
      File.join(tmpdir, self.class.generate_tmpname)
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
