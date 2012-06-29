module Rake
  class Pipeline
    # This class is for files that, when processing their inputs, may
    # find additional dependencies.
    #
    # For example, consider this file app.c:
    #
    #     #include "app.h"
    #     some_stuff();
    #
    # If we have a task that compiles app.c into app.o, it needs to
    # process app.c to look for additional dependencies specified
    # by the file itself.
    class DynamicFileTask < Rake::FileTask

      def has_dynamic_block?
        !!@dynamic
      end

      def last_manifest_entry
        application.last_manifest[name]
      end

      def manifest_entry
        application.manifest[name]
      end

      def manifest_entry=(new_entry)
        application.manifest[name] = new_entry
      end

      def needed?
        return true if super

        # if we have no manifest, this file task is needed
        return true unless last_manifest_entry

        # If any of this task's dynamic dependencies have changed,
        # this file task is needed
        last_manifest_entry.deps.each do |dep, time|
          return true if File.mtime(dep) > time
        end

        # Otherwise, it's not needed
        false
      end

      # Add a block that will return dynamic dependencies. This
      # block can assume that all static dependencies are up
      # to date.
      #
      # @return [DynamicFileTask] self
      def dynamic(&block)
        @dynamic = block
        self
      end

      # Invoke the task's dynamic block.
      def invoke_dynamic_block
        @dynamic.call(self)
      end

      # At runtime, we will call this to get dynamic prerequisites
      def dynamic_prerequisites
        @dynamic_prerequisites ||= begin
          # Try to avoid invoking the dynamic block if this file
          # is not needed. If so, we may have all the information
          # we need in the manifest file.
          if !needed? && last_manifest_entry
            mtime = last_manifest_entry.mtime
          end

          # If the output file of this task still exists and
          # it hasn't been updated, we can simply return the
          # list of dependencies in the manifest, which
          # come from the return value of the dynamic block
          # in a previous run.
          if File.exist?(name) && mtime == File.mtime(name)
            return last_manifest_entry.deps.map { |k,v| k }
          end

          # If we couldn't get the dynamic dependencies from
          # a previous run, invoke the dynamic block.
          invoke_dynamic_block
        end
      end

      # Override rake's invoke_prerequisites method to invoke
      # static prerequisites and then any dynamic prerequisites.
      def invoke_prerequisites(task_args, invocation_chain)
        super

        # If we don't have a dynamic block, just act like a regular FileTask.
        return unless has_dynamic_block?

        # Retrieve the dynamic prerequisites. If all goes well,
        # we will not have to invoke the dynamic block to do this.
        dynamics = dynamic_prerequisites

        # invoke dynamic prerequisites just as we would invoke
        # static prerequisites.
        dynamics.each do |prereq|
          task = lookup_prerequisite(prereq)
          prereq_args = task_args.new_scope(task.arg_names)
          task.invoke_with_call_chain(prereq_args, invocation_chain)
        end

        # Create a new manifest entry for each dynamic dependency.
        # When the pipeline finishes, these manifest entries will be written
        # to the file system.
        entry = Rake::Pipeline::ManifestEntry.new()

        dynamics.each do |dynamic|
          entry.deps.merge!(dynamic => mtime_or_now(dynamic))
        end

        self.manifest_entry = entry
      end

      # After invoking a task, add the mtime of the task's output
      # to its current manifest entry.
      def invoke_with_call_chain(*)
        super
        return unless has_dynamic_block?

        manifest_entry.mtime = mtime_or_now(name)
      end

    private
      # @return the mtime of the given file if it exists, and
      # the current time otherwise.
      def mtime_or_now(filename)
        File.file?(filename) ? File.mtime(filename) : Time.now
      end
    end
  end
end

