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
    #   end
    class GsubFilter < Filter
      # Arguments mimic String#gsub with one notable exception. 
      # String#gsub accepts a block where $1, $2, and friends are
      # accessible. Due to Ruby's scoping rules of these variables
      # they are not accssible inside the block itself. Instead they
      # are passed in as additional arguments. Here's an example:
      #
      # @example
      #   !!!ruby
      #   Rake::Pipeline::GsubFilter.new /(\w+)\s(\w+)/ do |entire_match, capture1, capture2|
      #     # process the match
      #   end
      #
      # @see String#gsub
      def initialize(*args, &block)
        @args, @block = args, block
        super() { |input| input }
      end

      # Implement the {#generate_output} method required by
      # the {Filter} API. In this case, simply loop through
      # the inputs and write String#gsub content to the output.
      #
      # @param [Array<FileWrapper>] inputs an Array of
      #   {FileWrapper} objects representing the inputs to
      #   this filter.
      # @param [FileWrapper] a single {FileWrapper} object
      #   representing the output.
      def generate_output(inputs, output)
        inputs.each do |input|
          if @block
            content = input.read.gsub(*@args) do |match|
              @block.call match, *$~.captures
            end
            output.write content
          else
            output.write input.read.gsub(*@args)
          end
        end
      end
    end
  end
end
