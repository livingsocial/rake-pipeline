class Rake::Pipeline
  module SpecHelpers

    # TODO: OS agnostic modules
    module FileUtils
      def mkdir_p(dir)
        system "mkdir", "-p", dir
      end

      def touch(file)
        system "touch", file
      end

      def rm_rf(dir)
        system "rm", "-rf", dir
      end

      def touch_p(file)
        dir = File.dirname(file)
        mkdir_p dir
        touch file
      end

      def age_existing_files
        old_time = Time.now - 10
        Dir[File.join(tmp, "**/*.js")].each do |file|
          File.utime(old_time, old_time, file)
        end
      end
    end

  end
end


