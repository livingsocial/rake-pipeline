require "digest"

module Rake
  class Pipeline
    # A Project controls the lifecycle of a series of Pipelines,
    # creating them from an Assetfile and recreating them if the
    # Assetfile changes.
    class Project
      # @return [Pipeline] the list of pipelines in the project
      attr_reader :pipelines

      attr_reader :maps

      # @return [String|nil] the path to the project's Assetfile
      #   or nil if it was created without an Assetfile.
      attr_reader :assetfile_path

      # @return [String|nil] the digest of the Assetfile the
      #   project was created with, or nil if the project
      #   was created without an Assetfile.
      attr_reader :assetfile_digest

      # @return [String] the directory path for temporary files
      attr_reader :tmpdir

      # @return [String] the directory path where pipelines will
      #   write their outputs by default
      attr_reader :default_output_root

      # @return [Array] a list of filters to be applied before
      #   the specified filters in every pipeline
      attr_writer :before_filters

      # @return [Array] a list of filters to be applied after
      #   the specified filters in every pipeline
      attr_writer :after_filters

      class << self
        # Configure a new project by evaluating a block with the
        # Rake::Pipeline::DSL::ProjectDSL class.
        #
        # @see Rake::Pipeline::Filter Rake::Pipeline::Filter
        #
        # @example
        #   Rake::Pipeline::Project.build do
        #     tmpdir "tmp"
        #     output "public"
        #
        #     input "app/assets" do
        #       concat "app.js"
        #     end
        #   end
        #
        # @return [Rake::Pipeline::Project] the newly configured project
        def build(&block)
          project = new
          project.build(&block)
        end

        # @return [Array[String]] an array of strings that will be
        #   appended to {#digested_tmpdir}.
        def digest_additions
          @digest_additions ||= []
        end

        # Set {.digest_additions} to a sorted copy of the given array.
        def digest_additions=(additions)
          @digest_additions = additions.sort
        end

        # Add a value to the list of strings to append to the digest
        # temp directory. Libraries can use this to add (for example)
        # their version numbers so that the pipeline will be rebuilt
        # if the library version changes.
        #
        # @example
        #   Rake::Pipeline::Project.add_to_digest(Rake::Pipeline::Web::Filters::VERSION)
        #
        # @param [#to_s] str a value to append to {#digested_tmpdir}.
        def add_to_digest(str)
          self.digest_additions << str.to_s
          self.digest_additions.sort!
        end
      end

      # @param [String|Pipeline] assetfile_or_pipeline
      #   if this a String, create a Pipeline from the Assetfile at
      #   that path. If it's a Pipeline, just wrap that pipeline.
      def initialize(assetfile_or_pipeline=nil)
        reset!
        if assetfile_or_pipeline.kind_of?(String)
          @assetfile_path = File.expand_path(assetfile_or_pipeline)
          rebuild_from_assetfile(@assetfile_path)
        elsif assetfile_or_pipeline
          @pipelines << assetfile_or_pipeline
        end
      end

      # Evaluate a block using the Rake::Pipeline::DSL::ProjectDSL
      # DSL against an existing project.
      def build(&block)
        DSL::ProjectDSL.evaluate(self, &block) if block
        self
      end

      # Invoke all of the project's pipelines.
      #
      # @see Rake::Pipeline#invoke
      def invoke
        pipelines.each(&:invoke)
      end

      # Invoke all of the project's pipelines, detecting any changes
      # to the Assetfile and rebuilding the pipelines if necessary.
      #
      # @return [void]
      # @see Rake::Pipeline#invoke_clean
      def invoke_clean
        @invoke_mutex.synchronize do
          if assetfile_path
            source = File.read(assetfile_path)
            if digest(source) != assetfile_digest
              rebuild_from_assetfile(assetfile_path, source)
            end
          end
          pipelines.each(&:invoke_clean)
        end
      end

      # Remove the project's temporary and output files.
      def clean
        files_to_clean.each { |file| FileUtils.rm_rf(file) }
      end

      # Clean out old tmp directories from the pipeline's
      # {Rake::Pipeline#tmpdir}.
      #
      # @return [void]
      def cleanup_tmpdir
        obsolete_tmpdirs.each { |dir| FileUtils.rm_rf(dir) }
      end

      # Set the default output root of this project and expand its path.
      #
      # @param [String] root this pipeline's output root
      def default_output_root=(root)
        @default_output_root = File.expand_path(root)
      end

      # Set the temporary directory for this project and expand its path.
      #
      # @param [String] root this project's temporary directory
      def tmpdir=(dir)
        @tmpdir = File.expand_path(dir)
      end

      # @return [String] A subdirectory of {#tmpdir} with the digest of
      #   the Assetfile's contents and any {.digest_additions} in its
      #   name.
      def digested_tmpdir
        suffix = assetfile_digest
        unless self.class.digest_additions.empty?
          suffix += "-#{self.class.digest_additions.join('-')}"
        end
        File.join(tmpdir, "rake-pipeline-#{suffix}")
      end

      # @return Array[String] a list of the paths to temporary directories
      #   that don't match the pipline's Assetfile digest.
      def obsolete_tmpdirs
        if File.directory?(tmpdir)
          Dir["#{tmpdir}/rake-pipeline-*"].sort.reject do |dir|
            dir == digested_tmpdir
          end
        else
          []
        end
      end

      # @return Array[String] a list of files to delete to completely clean
      #   out a project's temporary and output files.
      def files_to_clean
        setup_pipelines
        obsolete_tmpdirs + [digested_tmpdir] + output_files.map(&:fullpath)
      end

      # @return [Array[FileWrapper]] a list of the files that
      #   will be generated when this project is invoked.
      def output_files
        setup_pipelines
        pipelines.map(&:output_files).flatten
      end

      # Build a new pipeline and add it to our list of pipelines.
      def build_pipeline(input, glob=nil, &block)
        pipeline = Rake::Pipeline.build({
          :before_filters => @before_filters,
          :after_filters => @after_filters,
          :output_root => default_output_root,
          :tmpdir => digested_tmpdir
        }, &block)

        if input.kind_of?(Array)
          input.each { |x| pipeline.add_input(x) }
        elsif input.kind_of?(Hash)
          pipeline.inputs = input
        else
          pipeline.add_input(input, glob)
        end

        @pipelines << pipeline
        pipeline
      end

    private
      # Reset this project's internal state to the default values.
      #
      # @return [void]
      def reset!
        @pipelines = []
        @maps = {}
        @tmpdir = "tmp"
        @invoke_mutex = Mutex.new
        @default_output_root = @assetfile_digest = @assetfile_path = nil
      end

      # Reconfigure this project based on the Assetfile at path.
      #
      # @param [String] path the path to the Assetfile
      #   to use to configure the project.
      # @param [String] source if given, this string is
      #   evaluated instead of reading the file at assetfile_path.
      #
      # @return [void]
      def rebuild_from_assetfile(path, source=nil)
        reset!
        source ||= File.read(path)
        @assetfile_digest = digest(source)
        @assetfile_path = path
        build { instance_eval(source, path, 1) }
      end

      # Setup the pipeline so its output files will be up to date.
      def setup_pipelines
        pipelines.map(&:setup_filters)
      end

      # @return [String] the SHA1 digest of the given string.
      def digest(str)
        Digest::SHA1.hexdigest(str)
      end
    end
  end
end
