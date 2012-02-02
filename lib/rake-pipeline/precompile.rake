namespace :assets do
  desc "Precompile assets using Rake::Pipeline"
  task :precompile do
    config = Rails.application.config.rake_pipeline_assetfile
    Rake::Pipeline::Project.new(config).invoke
  end
end

