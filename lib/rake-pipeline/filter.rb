require "rake"

module Rake
  class Pipeline
    class Filter
      attr_accessor :input_files, :input_root
      attr_accessor :output_name, :output_root

      attr_writer :rake_application

      def self.processes_binary_files
        define_method(:encoding) { "BINARY" }
      end

      def encoding
        "UTF-8"
      end

      def outputs
        hash = {}

        input_files.each do |file|
          output = output_wrapper(output_name.call(file))

          hash[output] ||= []
          hash[output] << input_wrapper(file)
        end

        hash
      end

      def output_files
        input_files.inject([]) do |array, file|
          array |= [output_name.call(file)]
        end
      end

      def rake_application
        @rake_application || Rake.application
      end

      def rake_tasks
        outputs.map do |output, inputs|
          prerequisites = inputs.map(&:fullpath)
          prerequisites.each { |path| rake_application.define_task(Rake::FileTask, path) }

          rake_application.define_task(Rake::FileTask, output.fullpath => prerequisites) do
            output.create do
              generate_output(inputs, output)
            end
          end
        end
      end

    private
      def input_wrapper(file)
        FileWrapper.new(input_root, file, encoding)
      end

      def output_wrapper(file)
        FileWrapper.new(output_root, file, encoding)
      end
    end
  end
end
