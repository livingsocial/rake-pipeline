module Rake
  class Pipeline
    class InstallGenerator < Rails::Generators::Base

      desc "Install Rake::Pipeline in this Rails app"

      def disable_asset_pipeline_railtie
        say_status :config, "Updating configuration to remove asset pipeline"
        gsub_file app, "require 'rails/all'", <<-RUBY.strip_heredoc
          # Pick the frameworks you want:
          require "active_record/railtie"
          require "action_controller/railtie"
          require "action_mailer/railtie"
          require "active_resource/railtie"
          require "rails/test_unit/railtie"
        RUBY
      end

      # TODO: Support sprockets API
      def disable_asset_pipeline_config
        regex = /^\n?\s*#.*\n\s*(#\s*)?config\.assets.*\n/
        gsub_file app, regex, ''
        gsub_file Rails.root.join("config/environments/development.rb"), regex, ''
        gsub_file Rails.root.join("config/environments/production.rb"), regex, ''
      end

      def remove_assets_group
        regex = /^\n(#.*\n)+group :assets.*\n(.*\n)*?end\n/

        gsub_file "Gemfile", regex, ''
      end

      def enable_assets_in_development
        gsub_file "config/environments/development.rb", /^end/, "\n  config.rake_pipeline_enabled = true\nend"
      end

      # TODO: Support asset-pipeline like API
      def add_assetfile
        create_file "Assetfile", <<-RUBY.strip_heredoc
          # NOTE: The Assetfile will eventually be replaced with an asset-pipeline
          # compatible API. This is mostly important so that plugins can easily
          # inject into the pipeline.
          #
          # Depending on demand and how the API shakes out, we may retain the
          # Assetfile API but pull in the information from the Rails API.

          input "app/assets"
          output "public"

          match "*.js" do
            concat "application.js"
          end

          match "*.css" do
            concat "application.css"
          end

          # copy any remaining files
          concat
        RUBY
      end

    private
      def app
        @app ||= Rails.root.join("config/application.rb")
      end
    end
  end
end

