module Rake
  class Pipeline
    class SortedPipeline < Pipeline
      attr_accessor :pipeline, :comparator

      def output_files
        input_files.sort(&comparator)
      end

      # Override {Pipeline#finalize} to do nothing. We want to pass
      # on our unmatched inputs to the next part of the pipeline.
      #
      # @return [void]
      # @api private
      def finalize
      end
    end
  end
end
