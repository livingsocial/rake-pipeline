require "rake-pipeline/middleware"

module Rake
  class Pipeline
    class Railtie < ::Rails::Railtie
      config.rake_pipeline_enabled = false
      config.rake_pipeline_assetfile = 'Assetfile'

      initializer "rake-pipeline.assetfile" do |app|
        if config.rake_pipeline_enabled
          assetfile = File.join(Rails.root, config.rake_pipeline_assetfile)
          config.app_middleware.use(Rake::Pipeline::Middleware, assetfile)
        end
      end
    end
  end
end
