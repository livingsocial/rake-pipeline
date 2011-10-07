require "rake"

module Rake
  class Pipeline
    class Filter
      attr_accessor :input_files
      attr_accessor :output_name
      attr_accessor :input_root
      attr_accessor :output_root
      attr_accessor :filters

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

      def rake_tasks
        outputs.map do |output, inputs|
          prerequisites = inputs.map(&:fullpath)
          prerequisites.each { |path| Rake::FileTask.define_task(path) }

          Rake::FileTask.define_task(output.fullpath => prerequisites) do
            output.create do
              generate_output(inputs, output)
            end
          end
        end
      end

    private
      def input_wrapper(file)
        FileWrapper.new(input_root, file)
      end

      def output_wrapper(file)
        FileWrapper.new(output_root, file)
      end
    end
  end
end
