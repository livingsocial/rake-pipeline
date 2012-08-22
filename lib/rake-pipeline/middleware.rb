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
        project.invoke_clean
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

        return not_found(project.not_found_error_page)
      end

    private
      def response_for(file, status=200, fallback_response=nil)
        [ status, headers_for(file), fallback_response || File.open(file, "r") ]
      end

      def not_found(not_found_file)
        fallback = ["not found"] unless File.exist?(not_found_file)
        response_for(not_found_file, 404, fallback)
      end

      def file_for(path)
        project.pipelines.each do |pipeline|
          file = Dir[File.join(pipeline.output_root, path)].sort.first
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
