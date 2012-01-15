require "rake"

module Rake
  class Pipeline

    # A Filter is added to a pipeline and converts input files
    # into output files.
    #
    # Filters operate on FileWrappers, which abstract away the
    # root directory of a file, providing a relative path and
    # a mechanism for reading and writing.
    #
    #
    # For instance, a filter to wrap the contents of each file
    # in a JavaScript closure would look like:
    #
    #   !!!ruby
    #   require "json"
    #
    #   class ClosureFilter < Rake::Pipeline::Filter
    #     def generate_output(inputs, output)
    #       inputs.each do |input|
    #         output.write "(function() { #{input.read.to_json} })()"
    #       end
    #     end
    #   end
    #
    # A filter's files come from the input directory or the directory
    # owned by the previous filter, but filters are insulated from
    # this concern.
    #
    # You can call +path+ on a FileWrapper to get the file's relative
    # path, or `fullpath` to get its absolute path, but you should,
    # in general, not use `fullpath` but instead use methods of
    # FileWrapper like `read` and `write` that abstract the details
    # from you.
    #
    # @see ConcatFilter Rake::Pipeline::ConcatFilter for another
    #   example filter implementation.
    #
    # @abstract
    class Filter
      # @return [Array<FileWrapper>] an Array of FileWrappers that
      #   represent the inputs of this filter. The Pipeline will
      #   usually set this up.
      attr_accessor :input_files

      # @return [Proc] a block that returns the relative output
      #   filename for a particular input file. If the block accepts
      #   just one argument, it will be passed the input's path. If
      #   it accepts two, it will also be passed the input itself.
      attr_accessor :output_name_generator

      # @return [String] the root directory to write output files
      #   to. For the last filter in a pipeline, the pipeline will
      #   set this to the pipeline's output. For all other filters,
      #   the pipeline will create a temporary directory that it
      #   also uses when creating FileWrappers for the next filter's
      #   inputs.
      attr_accessor :output_root

      # @return [Array<Rake::Task>] an Array of Rake tasks created
      #   for this filter. Each unique output file will get a
      #   single task.
      attr_reader :rake_tasks

      # @return [Rake::Application] the Rake::Application that the
      #   filter should define new rake tasks on.
      attr_writer :rake_application

      # @return [Rake::Pipeline] the Rake::Pipeline that contains
      #   this filter.
      attr_accessor :pipeline

      attr_writer :file_wrapper_class

      # @param [Proc] block a block to use as the Filter's
      #   {#output_name_generator}.
      def initialize(&block)
        block ||= proc { |input| input }
        @output_name_generator = block
        @input_files = []
      end

      # Invoke this method in a subclass of Filter to declare that
      # it expects to work with BINARY data, and that data that is
      # not valid UTF-8 should be allowed.
      #
      # @return [void]
      def self.processes_binary_files
        define_method(:encoding) { "BINARY" }
      end

      # @return [Class] the class to use as the wrapper for output
      #   files.
      def file_wrapper_class
        @file_wrapper_class ||= FileWrapper
      end

      # Set the input files to a list of FileWrappers. The filter
      # will map these into equivalent FileWrappers with the
      # filter's encoding applied.
      #
      # By default, a filter's encoding is +UTF-8+, unless
      # it calls #processes_binary_files, which changes it to
      # +BINARY+.
      #
      # @param [Array<FileWrapper>] a list of FileWrapper objects
      def input_files=(files)
        @input_files = files.map do |file|
          file.with_encoding(encoding)
        end
      end

      # A hash of output files pointing at their associated input
      # files. The output names are created by applying the
      # {#output_name_generator} to each input file.
      #
      # For exmaple, if you had the following input files:
      #
      #     javascripts/jquery.js
      #     javascripts/sproutcore.js
      #     stylesheets/sproutcore.css
      #
      # And you had the following {#output_name_generator}:
      #
      #     !!!ruby
      #     filter.output_name_generator = proc do |filename|
      #       # javascripts/jquery.js becomes:
      #       # ["javascripts", "jquery", "js"]
      #       directory, file, ext = file.split(/[\.\/]/)
      #
      #       "#{directory}.#{ext}"
      #     end
      #
      # You would end up with the following hash:
      #
      #     !!!ruby
      #     {
      #       #<FileWrapper path="javascripts.js" root="#{output_root}> => [
      #         #<FileWrapper path="javascripts/jquery.js" root="#{previous_filter.output_root}">,
      #         #<FileWrapper path="javascripts/sproutcore.js" root="#{previous_filter.output_root}">
      #       ],
      #       #<FileWrapper path="stylesheets.css" root="#{output_root}"> => [
      #         #<FileWrapper path="stylesheets/sproutcore.css" root=#{previous_filter.output_root}">
      #       ]
      #     }
      #
      # Each output file becomes a Rake task, which invokes the +#generate_output+
      # method defined by the subclass of {Filter} with the Array of inputs and
      # the output (all as {FileWrapper}s).
      #
      # @return [Hash{FileWrapper => Array<FileWrapper>}]
      def outputs
        hash = {}

        input_files.each do |file|
          outputs = output_paths(file)

          output_wrappers(file).each do |output|
            hash[output] ||= []
            hash[output] << file
          end
        end

        hash
      end

      # An Array of the {FileWrapper} objects that rerepresent this filter's
      # output files. It is the same as +outputs.keys+.
      #
      # @see #outputs
      # @return [Array<FileWrapper>]
      def output_files
        input_files.map { |file| output_wrappers(file) }.flatten.uniq
      end

      # The Rake::Application that the filter should define new tasks on.
      #
      # @return [Rake::Application]
      def rake_application
        @rake_application || Rake.application
      end

      # Generate the Rake tasks for the output files of this filter.
      #
      # @see #outputs #outputs (for information on how the output files are determined)
      # @return [void]
      def generate_rake_tasks
        @rake_tasks = outputs.map do |output, inputs|
          dependencies = inputs.map(&:fullpath)

          dependencies.each { |path| create_file_task(path) }

          create_file_task(output.fullpath, dependencies) do
            output.create { generate_output(inputs, output) }
          end
        end
      end

    private
      # @attr_reader
      def encoding
        "UTF-8"
      end

      def create_file_task(output, deps=[], &block)
        rake_application.define_task(Rake::FileTask, output => deps, &block)
      end

      def output_wrappers(input)
        output_paths(input).map do |path|
          file_wrapper_class.new(output_root, path, encoding)
        end
      end

      def output_paths(input)
        args = [ input.path ]
        args << input if output_name_generator.arity == 2
        Array(output_name_generator.call(*args))
      end
    end
  end
end
