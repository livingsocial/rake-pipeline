namespace :assets do
  desc "Precompile assets using Rake::Pipeline"
  task :precompile do
    config = Rails.application.config.rake_pipeline_assetfile
    Rake::Pipeline::Runner.from_assetfile(config).invoke(:build, [])
  end
end

