module Rake
  class Pipeline
    # A built in filter that applies String#gsub behavior.
    #
    # @example
    #   !!!ruby
    #   Pipeline.build do
    #     input "app/assets", "**/*.js"
    #     output "public"
    #
    #     # replace javascript comments
    #     filter(Rake::Pipeline::GsubFilter, /\//\w+$/, '')
    #
    #     # another example
    #     filter(Rake::Pipeline::GsubFilter, /\//\w+$/) do |comment|
    #       # process comment in some way
    #       # comment is replaced with this block's 
    #       # return value
    #     end
    #   end
    class GsubFilter < Filter
      # Arguments mimic String#gsub
      #
      # @see String#gsub
      def initialize(*args, &block)
        @args, @bock = args, block
        super() { |input| input }
      end

      # Implement the {#generate_output} method required by
      # the {Filter} API. In this case, simply loop through
      # the inputs and write String#gsub content to the output
      #
      # Recall that this method will be called once for each
      # unique output file.
      #
      # @param [Array<FileWrapper>] inputs an Array of
      #   {FileWrapper} objects representing the inputs to
      #   this filter.
      # @param [FileWrapper] a single {FileWrapper} object
      #   representing the output.
      def generate_output(inputs, output)
        inputs.each do |input|
          output.write input.read.gsub(*@args, &@block)
        end
      end
    end
  end
end
