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

      class DynamicImportFilter < Rake::Pipeline::Filter
        def additional_dependencies(input)
          includes(input)
        end

        def includes(input)
          input.read.scan(/^@import\(\"(.*)\"\)$/).map(&:first).map do |inc|
            File.join(input.root, "#{inc}.import")
          end
        end

        def generate_output(inputs, output)
          inputs.each do |input|
            output.write input.read
            includes(input).each do |inc|
              output.write File.read(inc)
            end
          end
        end
      end
    end
  end
end
