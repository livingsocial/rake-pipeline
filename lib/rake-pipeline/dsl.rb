module Rake
  class Pipeline
    # This class exists purely to provide a convenient DSL for
    # configuring a pipeline.
    #
    # All instance methods of {DSL} are available in the context
    # the block passed to +Rake::Pipeline.+{Pipeline.build}.
    #
    # When configuring a pipeline, you *must* provide both a
    # root, and a series of files using {#input}.
    class DSL
      # @return [Pipeline] the pipeline the DSL should configure
      attr_reader :pipeline

      # Configure a pipeline with a passed in block.
      #
      # @param [Pipeline] pipeline the pipeline that the DSL
      #   should configure.
      # @param [Proc] block the block describing the
      #   configuration. This block will be evaluated in
      #   the context of a new instance of {DSL}
      # @return [void]
      def self.evaluate(pipeline, &block)
        new(pipeline).instance_eval(&block)
        copy_filter = Rake::Pipeline::ConcatFilter.new
        copy_filter.output_name_generator = proc { |input| input }
        pipeline.add_filter(copy_filter)
      end

      # Create a new {DSL} to configure a pipeline.
      #
      # @param [Pipeline] pipeline the pipeline that the DSL
      #   should configure.
      # @return [void]
      def initialize(pipeline)
        @pipeline = pipeline
      end

      # Define the input location and files for the pipeline.
      #
      # @example
      #   !!!ruby
      #   Rake::Pipeline.build do
      #     input "app/assets", "**/*.js"
      #     # ...
      #   end
      #
      # @param [String] root the root path where the pipeline
      #   should find its input files.
      # @param [String] glob a file pattern that represents
      #   the list of all files that the pipeline should
      #   process within +root+. The default is +"**/*"+.
      # @return [void]
      def input(root, glob="**/*")
        pipeline.add_input root, glob
      end

      # Add a filter to the pipeline.
      #
      # In addition to a filter class, {#filter} takes a
      # block that describes how the filter should map
      # input files to output files.
      #
      # By default, the block maps an input file into
      # an output file with the same name.
      #
      # Any additional arguments passed to {#filter} will
      # be passed on to the filter class's constructor.
      #
      # @see Filter#outputs Filter#output (for an example
      #   of how a list of input files gets mapped to
      #   its outputs)
      #
      # @param [Class] filter_class the class of the filter.
      # @param [Array] ctor_args a list of arguments to pass
      #   to the filter's constructor.
      # @param [Proc] block an output file name generator.
      # @return [void]
      def filter(filter_class, *ctor_args, &block)
        filter = filter_class.new(*ctor_args, &block)
        pipeline.add_filter(filter)
      end

      # Apply a number of filters, but only to files matching
      # a particular pattern.
      #
      # Inside the block passed to {#match match}, you may
      # specify any number of filters that should be applied
      # to files matching the pattern.
      #
      # @param [String] pattern a glob pattern to match
      # @param [Proc] block a block that supplies filters
      # @return [Matcher]
      #
      # @example
      #   !!!ruby
      #   Pipeline.build do
      #     input "app/assets"
      #     output "public"
      #
      #     # compile coffee files into JS files
      #     match "*.coffee" do
      #       filter CompileCoffee do |input|
      #         input.sub(/coffee$/, "js")
      #       end
      #     end
      #
      #     # because the previous step converted coffeee
      #     # into JS, the coffee files will be included here
      #     match "*.js" do
      #       filter MinifyFilter
      #       filter Rake::Pipeline::ConcatFilter, "application.js"
      #     end
      #   end
      def match(pattern, &block)
        matcher = pipeline.copy(Matcher, &block)
        matcher.glob = pattern
        pipeline.add_filter matcher
        matcher
      end

      # Specify the output directory for the pipeline.
      #
      # @param [String] root the output directory.
      # @return [void]
      def output(root)
        pipeline.output_root = root
      end

      # Specify the location of the temporary directory.
      # Filters will store intermediate build artifacts
      # here.
      #
      # This defaults "tmp" in the current working directory.
      #
      # @param [String] root the temporary directory
      # @return [void]
      def tmpdir(root)
        pipeline.tmpdir = root
      end

      # A helper method for adding a concat filter to
      # the pipeline.
      # If the first argument is an Array, it adds a new
      # {OrderingConcatFilter}, otherwise it adds a new
      # {ConcatFilter}.
      #
      # @see OrderingConcatFilter#initialize
      # @see ConcatFilter#initialize
      def concat(*args, &block)
        if args.first.kind_of?(Array)
          filter(Rake::Pipeline::OrderingConcatFilter, *args, &block)
        else
          filter(Rake::Pipeline::ConcatFilter, *args, &block)
        end
      end
    end
  end
end


