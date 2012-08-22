require "rake-pipeline/middleware"
require "rack/server"

module Rake
  class Pipeline
    class Server < Rack::Server
      def app
        config = "Assetfile"

        Middleware.new(->{}, config)
      end
    end
  end
end
