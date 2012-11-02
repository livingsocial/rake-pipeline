require "rake-pipeline/middleware"
require "rack/server"

module Rake
  class Pipeline
    class Server < Rack::Server
      def app
        not_found = proc { [404, { "Content-Type" => "text/plain" }, ["not found"]] }
        project = Rake::Pipeline::Project.new "Assetfile"

        Middleware.new(not_found, project)
      end
    end
  end
end
