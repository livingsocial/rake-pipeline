require "thor"

module Rake
  class Pipeline
    class CLI < Thor
      class_option :assetfile, :default => "Assetfile", :aliases => "-c"
      default_task :server

      desc "build", "Build the project."
      method_option :pretend, :type => :boolean, :aliases => "-p"
      method_option :clean, :type => :boolean, :aliases => "-C"
      def build
        if options[:pretend]
          runner.pipeline.setup_filters
          runner.output_files.each do |file|
            say_status :create, relative_path(file)
          end
        else
          options[:clean] ? runner.clean : runner.cleanup_tmpdir
          runner.invoke
        end
      end

      desc "clean", "Remove the pipeline's temporary and output files."
      method_option :pretend, :type => :boolean, :aliases => "-p"
      def clean
        if options[:pretend]
          runner.pipeline.setup_filters
          runner.files_to_clean.each do |file|
            say_status :remove, relative_path(file)
          end
        else
          runner.clean
        end
      end

      desc "server", "Run the Rake::Pipeline preview server."
      def server
        require "rake-pipeline/server"
        Rake::Pipeline::Server.new.start
      end

    private
      def runner
        @runner ||= Rake::Pipeline::Runner.new(options[:assetfile])
      end

      # @param [FileWrapper|String] path
      # @return [String] The path to the file with the current
      #   directory stripped out.
      def relative_path(path)
        pathstr = path.respond_to?(:fullpath) ? path.fullpath : path
        pathstr.sub(%r|#{Dir.pwd}/|, '')
      end
    end
  end
end

