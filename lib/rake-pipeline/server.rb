require "rake-pipeline/middleware"
require "rack/server"

module Rake
  class Pipeline
    class Server < Rack::Server
      def app
        not_found = proc { [404, { "Content-Type" => "text/plain" }, ["not found"]] }
        config = "Assetfile"

        Middleware.new(not_found, config)
      end
    end
  end
end
