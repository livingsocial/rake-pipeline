require "listen"
require "logger"

module Rake
  class Pipeline
    class Watcher
      attr_reader :logger

      def initialize(project)
        @project = project
        @listeners = []
        @logger = Logger.new(STDOUT)
      end

      def start
        project = @project

        build_proc = Proc.new do |modified, added, removed|
          # Determine if we need to do a clean build, which is only the case if
          #   files were added/deleted, or the Assetfile itself changed.
          clean = added.any? || removed.any? || modified.include?('Assetfile')

          logger.info "#{Time.now}:#{" reloading &" if clean} building project..."
          begin
            method = clean ? :invoke_clean : :invoke
            project.send method
            logger.info "done"
          rescue Exception => e
            logger.error "RAKEP ERROR: #{e.message}"
          end
        end

        # Watch for file changes in the inputs or the Assetfile.
        watched_inputs(project).each do |root, filter|
          listener = Listen.to(root, :relative_paths => true)
          listener = listener.filter(filter) if filter.is_a?(Regexp)
          listener = listener.change(&build_proc)
          @listeners << listener
        end

        # Build it once when we start up, and then start watching for changes.
        build_proc.call(['Assetfile'], [], [])
        @listeners.each{|l| l.start(false) }
      end

      def stop
        @listeners.each{|l| l.stop }
        @listeners = []
      end


      # Get the paths and globs to watch for changes, which is all the inputs
      #   plus the Assetfile
      def watched_inputs(project)
        inputs = [[".", /^Assetfile$/]]
        matcher = Matcher.new
        project.pipelines.each do |pipeline|
          pipeline.inputs.each do |k, v|
            matcher.glob = v
            inputs << [k, matcher.pattern]
          end
        end
        inputs
      end

    end
  end
end
