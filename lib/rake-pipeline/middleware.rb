require "rack"

module Rake
  class Pipeline
    class Middleware
      attr_accessor :pipeline

      def initialize(app)
        @app = app
      end

      def call(env)
        pipeline.invoke_clean

        path = env["PATH_INFO"]
        file = Dir[File.join(pipeline.output_root, path)].first

        if file
          content_type = Rack::Mime.mime_type(File.extname(path), "text/plain")
          [200, { "Content-Type" => content_type }, File.open(file, "r")]
        else
          @app.call(env)
        end
      end
    end
  end
end
