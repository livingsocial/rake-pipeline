class Rake::Pipeline
  module SpecHelpers

    module Filters
      ConcatFilter = Rake::Pipeline::ConcatFilter

      class StripAssertsFilter < Rake::Pipeline::Filter
        def generate_output(inputs, output)
          inputs.each do |input|
            output.write input.read.gsub(%r{^\s*assert\(.*\)\s*;?\s*$}m, '')
          end
        end
      end
    end
  end
end
