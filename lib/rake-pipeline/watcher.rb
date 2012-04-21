require "fssm"

module Rake
  class Pipeline
    class Watcher

      def initialize(project)
        @project = project
      end

      def start
        project = @project
        build_proc = generate_build_proc(project)
        monitor = FSSM::Monitor.new

        # Watch for file changes in the inputs or the Assetfile.
        # If files are added or deleted, or the Assetfile changes,
        #    do a full invoke_clean;
        #    otherwise, just do a regular invoke.
        watched_inputs(project).each do |root, input_glob|
          monitor.path root do
            glob input_glob
            update {|base, relative| build_proc.call(relative == 'Assetfile')}
            create {|base, relative| build_proc.call(true)}
            delete {|base, relative| build_proc.call(true)}
          end
        end

        # Build it once when we start up, and then start watching for changes.
        build_proc.call(false)
        monitor.run
      end


      # Get the paths and globs to watch for changes, which is all the inputs
      #   plus the Assetfile
      def watched_inputs(project)
        inputs = {"." => ['Assetfile']}
        project.pipelines.each do |pipeline|
          pipeline.inputs.each do |k, v|
            inputs[k] ||= []
            inputs[k] << v
          end
        end
        inputs
      end

      private

      def generate_build_proc(project)
        Proc.new do |clean|
          puts "#{Time.now}:#{" reloading &" if clean} building project..."
          begin
            method = clean ? :invoke_clean : :invoke
            project.send method
            puts "done"
          rescue Exception => e
            puts "RAKEP ERROR: #{e.message}"
          end
        end
      end

    end
  end
end
