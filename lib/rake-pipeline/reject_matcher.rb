module Rake
  class Pipeline
    # A RejectMatcher is a pipeline that does no processing. It
    # simply filters out some files. You can use this when
    # you have more complex logic that doesn't fit nicely
    # in a glob.
    #
    # You can pass a block or a glob (just like {DSL#match}).
    # Files matching the glob will be rejected from the pipeline.
    # Files are rejected when the block evaluates to true. Specify
    # either a glob or a block.
    #
    # In general, you should not use RejectMatcher directly. Instead use
    # {DSL#reject} in the block passed to {Pipeline.build}.
    class RejectMatcher < Matcher
      attr_accessor :block

      def output_files
        input_files.reject do |file|
          if block
            block.call file
          else
            file.path =~ @pattern
          end
        end
      end
    end
  end
end
