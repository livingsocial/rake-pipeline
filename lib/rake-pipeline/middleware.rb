require "rack"

module Rake
  class Pipeline
    # This middleware is used to provide a server that will continuously
    # compile your files on demand.
    #
    # @example
    #   !!!ruby
    #   use Rake::Pipeline::Middleware, Rake::Pipeline.build {
    #     input "app/assets"
    #     output "public"
    #
    #     ...
    #   }
    class Middleware
      attr_accessor :project

      # @param [#call] app a Rack application
      # @param [String|Rake::Pipeline] pipeline either a path to an
      #   Assetfile to use to build a pipeline, or an existing pipeline.
      def initialize(app, pipeline)
        @app = app
        @project = Rake::Pipeline::Project.new(pipeline)
      end

      # Automatically compiles your assets if required and
      # serves them up.
      #
      # @param [Hash] env a Rack environment
      # @return [Array(Fixnum, Hash, #each)] A rack response
      def call(env)
        path = env["PATH_INFO"]

        if project.maps.has_key?(path)
          return project.maps[path].call(env)
        end

        if filename = file_for(path)
          if File.directory?(filename)
            index = File.join(filename, "index.html")
            filename = File.file?(index) ? index : nil
          end

          if filename
            return response_for(filename)
          end
        end

        @app.call(env)
      end

    private
      def response_for(file)
        [ 200, headers_for(file), File.open(file, "r") ]
      end

      def file_for(path)
        project.pipelines.each do |pipeline|
          file = Dir[File.join(pipeline.output_root, path)].first
          return file unless file.nil?
        end
        nil
      end

      def headers_for(path)
        mime = Rack::Mime.mime_type(File.extname(path), "text/plain")
        { "Content-Type" => mime }
      end
    end
  end
end
