require "rack"

module Rake
  class Pipeline
    class Middleware
      attr_accessor :pipeline

      def initialize(app)
        @app = app
        @pipeline = nil
      end

      def call(env)
        pipeline.invoke_clean
        path = env["PATH_INFO"]

        if filename = file_for(path)
          if File.directory?(filename)
            index = File.join(filename, "index.html")
            filename = index if File.file?(index)
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
        Dir[File.join(pipeline.output_root, path)].first
      end

      def headers_for(path)
        mime = Rack::Mime.mime_type(File.extname(path), "text/plain")
        { "Content-Type" => mime }
      end
    end
  end
end
