module Rake
  class Pipeline
    module DSL
      # This class exists purely to provide a convenient DSL for
      # configuring a project.
      #
      # All instance methods of {ProjectDSL} are available in the context
      # the block passed to +Rake::Pipeline::Project.+{Project.build}.
      #
      # When configuring a project, you *must* provide an output root
      # and a series of files using at least one {#input} block.
      class ProjectDSL
        # @return [Project] the project the DSL should configure
        attr_reader :project

        # Configure a project with a passed in block.
        #
        # @param [Project] project the project that the ProjectDSL
        #   should configure.
        # @param [Proc] block the block describing the
        #   configuration. This block will be evaluated in
        #   the context of a new instance of {ProjectDSL}
        # @return [void]
        def self.evaluate(project, &block)
          new(project).instance_eval(&block)
        end

        # Create a new {ProjectDSL} to configure a project.
        #
        # @param [Project] project
        #   the project that the ProjectDSL should configure.
        # @return [void]
        def initialize(project)
          @project = project
          @before_filters = []
          @after_filters = []
          @project.before_filters = @before_filters
          @project.after_filters = @after_filters
        end

        # Add a filter to every input block. The parameters
        # to +before_filter+ are the same as the parameters
        # to {PipelineDSL#filter}.
        #
        # Filters will be executed before the specified
        # filters in reverse of insertion order.
        #
        # @see {PipelineDSL#filter}
        def before_filter(klass, *args, &block)
          @before_filters.unshift [klass, args, block]
        end

        # Add a filter to every input block. The parameters
        # to +after_filter+ are the same as the parameters
        # to {PipelineDSL#filter}.
        #
        # Filters will be executed after the specified
        # filters in insertion order.
        #
        # @see {PipelineDSL#filter}
        def after_filter(klass, *args, &block)
          @after_filters.push [klass, args, block]
        end

        # Specify the default output directory for the project.
        #
        # Pipelines created in this project will place their
        # outputs here unless the value is overriden in their
        # {#input} block.
        #
        # @param [String] root the output directory.
        # @return [void]
        def output(root)
          project.default_output_root = root
        end

        # Specify the location of the root temporary directory.
        #
        # Pipelines will store intermediate build artifacts
        # in a subdirectory of this directory.
        #
        # This defaults to "tmp" in the current working directory.
        #
        # @param [String] root the temporary directory
        # @return [void]
        def tmpdir(root)
          project.tmpdir = root
        end

        # Add a new pipeline with the given inputs to the project.
        #
        # @see Project.build_pipeline
        def input(*inputs, &block)
          # Allow pipelines without a specified block. This is possible
          # if before and after filters are all that are needed for a
          # given input.
          block = proc {} unless block_given?
          project.build_pipeline(*inputs, &block)
        end
        alias inputs input

        def map(path, &block)
          project.maps[path] = block
        end
      end
    end
  end
end
