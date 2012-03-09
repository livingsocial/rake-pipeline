module Rake
  class Pipeline
    # A built-in filter that simply accepts a series
    # of inputs and concatenates them into output files
    # based on the output file name generator.
    #
    # @example
    #   !!!ruby
    #   Pipeline.build do
    #     input "app/assets", "**/*.js"
    #     output "public"
    #
    #     # create a concatenated output file for each
    #     # directory of inputs.
    #     filter(Rake::Pipeline::ConcatFilter) do |input|
    #       # input files will look something like:
    #       #   javascripts/admin/main.js
    #       #   javascripts/admin/app.js
    #       #   javascripts/users/main.js
    #       #
    #       # and the outputs will look like:
    #       #   javascripts/admin.js
    #       #   javascripts/users.js
    #       directory = File.dirname(input)
    #       ext = File.extname(input)
    #
    #       "#{directory}#{ext}"
    #     end
    #   end
    class ConcatFilter < Rake::Pipeline::Filter
      # @param [String] string the name of the output file to
      #   concatenate inputs to.
      # @param [Proc] block a block to use as the Filter's
      #   {#output_name_generator}.
      def initialize(string=nil, &block)
        block = proc { string } if string
        super(&block)
      end

      # @method encoding
      # @return [String] the String +"BINARY"+
      processes_binary_files

      # implement the {#generate_output} method required by
      # the {Filter} API. In this case, simply loop through
      # the inputs and write their contents to the output.
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
          output.write input.read
        end
      end
    end
  end
end
