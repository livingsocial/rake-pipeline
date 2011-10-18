module Rake
  class Pipeline
    class ConcatFilter < Rake::Pipeline::Filter
      processes_binary_files

      def generate_output(inputs, output)
        inputs.each do |input|
          output.write input.read
        end
      end
    end
  end
end
