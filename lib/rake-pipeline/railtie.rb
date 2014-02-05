require "rake-pipeline/middleware"

module Rake
  class Pipeline
    # Use Rake::Pipeline inside of Rails 3.x. To use, simply add
    # Rake::Pipeline to your +Gemfile+:
    #
    #   !!!ruby
    #   gem 'rake-pipeline'
    #
    # Then, activate it in development mode. In config/development.rb:
    #
    #   !!!ruby
    #   config.rake_pipeline_enabled = true
    #
    class Railtie < ::Rails::Railtie
      config.rake_pipeline_enabled = false
      config.rake_pipeline_assetfile = 'Assetfile'

      rake_tasks do
        load "rake-pipeline/precompile.rake"
      end

      initializer "rake-pipeline.assetfile" do |app|
        if config.rake_pipeline_enabled
          assetfile = File.join(Rails.root, config.rake_pipeline_assetfile)
          if File.exists?(assetfile)
            project = Rake::Pipeline::Project.new assetfile

            config.app_middleware.insert ActionDispatch::Static, Rake::Pipeline::Middleware, project
          else
            puts "Warning from Rake-Pipeline: There is no Assetfile. You should create one first."
          end
        end
      end
    end
  end
end
