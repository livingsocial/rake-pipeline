module Rake
  class Pipeline
    module DSL
      # This class is used by {ProjectDSL} to provide a convenient DSL for
      # configuring a pipeline.
      #
      # All instance methods of {PipelineDSL} are available in the context
      # the block passed to +Rake::Pipeline.+{Pipeline.build}.
      class PipelineDSL
        # @return [Pipeline] the pipeline the DSL should configure
        attr_reader :pipeline

        # Configure a pipeline with a passed in block.
        #
        # @param [Pipeline] pipeline the pipeline that the PipelineDSL
        #   should configure.
        # @param [Proc] block the block describing the
        #   configuration. This block will be evaluated in
        #   the context of a new instance of {PipelineDSL}
        # @return [void]
        def self.evaluate(pipeline, options, &block)
          dsl = new(pipeline)

          # If any before filters, apply them to the pipeline.
          # They will be run in reverse of insertion order.
          if before_filters = options[:before_filters]
            before_filters.each do |klass, args, block|
              dsl.filter klass, *args, &block
            end
          end

          # Evaluate the block in the context of the DSL.
          dsl.instance_eval(&block)

          # If any after filters, apply them to the pipeline.
          # They will be run in insertion order.
          if after_filters = options[:after_filters]
            after_filters.each do |klass, args, block|
              dsl.filter klass, *args, &block
            end
          end

          # the FinalizingFilter should always come after all
          # user specified after filters
          pipeline.finalize
        end

        # Create a new {PipelineDSL} to configure a pipeline.
        #
        # @param [Pipeline] pipeline the pipeline that the PipelineDSL
        #   should configure.
        # @return [void]
        def initialize(pipeline)
          @pipeline = pipeline
        end

        # Add an input location and files to a pipeline.
        #
        # @example
        #   !!!ruby
        #   Rake::Pipeline::Project.build do
        #     input "app" do
        #       input "assets", "**/*.js"
        #       # ...
        #     end
        #   end
        #
        # @param [String] root the root path where the pipeline
        #   should find its input files.
        # @param [String] glob a file pattern that represents
        #   the list of files that the pipeline should
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
        #   Rake::Pipeline::Project.build do
        #     output "public"
        #
        #     input "app/assets" do
        #       # compile coffee files into JS files
        #       match "*.coffee" do
        #         coffee_script
        #       end
        #
        #       # because the previous step converted coffeee
        #       # into JS, the coffee files will be included here
        #       match "*.js" do
        #         uglify
        #         concat "application.js"
        #       end
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
        alias_method :copy, :concat
      end
    end
  end
end
