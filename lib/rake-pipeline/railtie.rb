module Rake
  class Pipeline
    class Railtie < ::Rails::Railtie
      config.rake_pipeline_enabled = false
      config.rake_pipeline_assetfile = File.join(RAILS_ROOT, 'AssetFile')

      initializer do |app|
        if config.rake_pipeline_enabled
          config.middleware.use(Rake::Pipeline::Middleware, config.rake_pipeline_assetfile)
        end
      end
    end
  end
end
