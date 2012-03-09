require 'rake-pipeline/middleware'

Rails.configuration.after_initialize do
  if defined?(RAKEP_ENABLED) && RAKEP_ENABLED
    assetfile = defined?(RAKEP_ASSETFILE) ? RAKEP_ASSETFILE : 'Assetfile'
    Rails.configuration.middleware.use(Rake::Pipeline::Middleware, assetfile)
  end
end
