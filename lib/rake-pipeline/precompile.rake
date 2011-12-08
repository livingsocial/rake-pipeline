namespace :assets do
  desc "Precompile assets using Rake::Pipeline"
  task :precompile do
    config = Rails.application.config.rake_pipeline_assetfile
    pipeline_source = File.read(config)
    pipeline = Rake::Pipeline.class_eval "build do\n#{pipeline_source}\nend", config, 1
    pipeline.invoke
  end
end

