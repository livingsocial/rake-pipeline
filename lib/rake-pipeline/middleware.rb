require "rack"

module Rake
  class Pipeline
    class Middleware
      attr_accessor :pipelines

      def initialize(app)
        @app = app
        @pipelines = []
      end

      def call(env)
        for pipeline in @pipelines
          pipeline.invoke_clean

          path = env["PATH_INFO"]
          file = Dir[File.join(pipeline.output_root, path)].first
        end

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
