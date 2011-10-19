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
          [ 200, headers_for(path), File.open(filename, "r") ]
        else
          @app.call(env)
        end
      end

    private
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
