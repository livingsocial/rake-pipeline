require "thor"

module Rake
  class Pipeline
    # A Runner controls the lifecycle of a Pipeline, creating
    # it from an Assetfile and recreating it if the Assetfile
    # changes.
    #
    class Runner < Thor
      include Thor::Actions

      # @return [Pipeline] the pipeline this Runner is controlling.
      attr_reader :pipeline

      # @return [String|nil] the path to the {#pipeline}'s Assetfile
      #   or nil if it was created without an Assetfile.
      attr_reader :assetfile_path

      # @return [String|nil] the digest of the Assetfile the
      #   {#pipeline} was created with, or nil if {#pipeline}
      #   was created without an Assetfile.
      attr_reader :assetfile_digest

      class_option :assetfile, :default => "Assetfile", :aliases => "-c"

      default_task :server

      desc "build", "Build the project."
      method_option :pretend, :type => :boolean, :aliases => "-p"
      def build
        if options["pretend"]
          pipeline.setup_filters
          pipeline.output_files.each { |dir| say_status(:create, dir.fullpath) }
        else
          cleanup_tmpdir
          pipeline.invoke
        end
      end

      desc "clean", "Remove the pipeline's temporary and output files."
      method_option :pretend, :type => :boolean, :aliases => "-p"
      def clean
        pipeline.setup_filters
        files_to_clobber.each { |dir| remove_dir dir }
      end

      desc "server", "Run the Rake::Pipeline preview server."
      def server
        require "rake-pipeline/server"
        Rake::Pipeline::Server.new.start
      end

      # @param [String|Rake::Pipeline] assetfile_or_pipeline
      #   if this a String, create a Rake::Pipeline from the
      #   Assetfile at that path. If it's a Rake::Pipeline,
      #   just wrap that pipeline.
      def self.from_assetfile(assetfile_or_pipeline)
        if assetfile_or_pipeline.is_a?(String)
          new([], :assetfile => File.expand_path(assetfile_or_pipeline))
        else
          new([], :pipeline => assetfile_or_pipeline)
        end
      end

      def initialize(*)
        super
        if options["pipeline"]
          @pipeline = options["pipeline"]
        else
          @assetfile_path = File.expand_path(options["assetfile"])
          build_pipeline
        end
      end

      no_tasks do
        # Clean out old tmp directories from the pipeline's
        # {Rake::Pipeline#tmpdir}.
        #
        # @return [void]
        def cleanup_tmpdir
          pipeline.setup_filters
          obsolete_tmpdirs.each { |dir| remove_dir dir }
        end

        # Invoke the pipeline, detecting any changes to the Assetfile
        # and rebuilding the pipeline if necessary.
        #
        # @return [void]
        # @see Rake::Pipeline#invoke_clean
        def invoke_clean
          if assetfile_path
            assetfile_source = File.read(assetfile_path)
            if digest(assetfile_source) != assetfile_digest
              build_pipeline(assetfile_source)
            end
          end
          pipeline.invoke_clean
        end

        # @return [String] the directory name to use as the pipeline's
        #   {Rake::Pipeline#tmpsubdir}.
        def digested_tmpdir
          "rake-pipeline-#{assetfile_digest}"
        end
      end

    private
      # Build a new pipeline based on the Assetfile at
      # {#assetfile_path}
      #
      # @return [void]
      def build_pipeline(assetfile_source=nil)
        assetfile_source ||= File.read(assetfile_path)
        @assetfile_digest = digest(assetfile_source)
        @pipeline = Rake::Pipeline.class_eval("build do\n#{assetfile_source}\nend", assetfile_path, 1)
        @pipeline.tmpsubdir = digested_tmpdir
        cleanup_tmpdir
      end

      # @return [String] the SHA1 digest of the given string.
      def digest(str)
        (Digest::SHA1.new << str).to_s
      end

      # @return Array[String] a list of the paths to temporary directories
      #   that don't match the pipline's Assetfile digest.
      def obsolete_tmpdirs
        if File.directory?(pipeline.tmpdir)
          Dir["#{pipeline.tmpdir}/rake-pipeline-*"].sort.reject do |dir|
            dir == "#{pipeline.tmpdir}/#{digested_tmpdir}"
          end
        else
          []
        end
      end

      # @return Array[String] a list of files to delete to completely clean
      #   out a pipeline's temporary and output files.
      def files_to_clobber
        obsolete_tmpdirs +
          ["#{pipeline.tmpdir}/#{digested_tmpdir}"] +
          pipeline.output_files.map(&:fullpath)
      end
    end
  end
end
