require 'rake-pipeline/middleware'

Rails.configuration.after_initialize do
  if defined?(RAKEP_ENABLED) && RAKEP_ENABLED
    assetfile = defined?(RAKEP_ASSETFILE) ? RAKEP_ASSETFILE : 'Assetfile'
    project = Rake::Pipeline::Project.new assetfile

    Rails.configuration.middleware.use Rake::Pipeline::Middleware, project
  end
end
