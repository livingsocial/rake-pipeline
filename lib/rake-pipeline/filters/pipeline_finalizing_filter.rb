module Rake
  class Pipeline
    # @private
    #
    # A built-in filter that copies a pipeline's generated files over
    # to its output.
    class PipelineFinalizingFilter < ConcatFilter

      # @return [Array[FileWrapper]] a list of the pipeline's
      # output files, excluding any files that were originally
      # inputs to the pipeline, meaning they weren't processed
      # by any filter and should not be copied to the output.
      def input_files
        pipeline_input_files = pipeline.input_files
        super.reject { |file| pipeline_input_files.include?(file) }
      end
    end
  end
end
