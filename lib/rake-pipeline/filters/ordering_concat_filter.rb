class Rake::Pipeline
  # A filter that concats files in a specified order.
  #
  # @example
  #   !!!ruby
  #   Rake::Pipeline.build do
  #     input "app/assets", "**/*.js"
  #     output "public"
  #
  #     # Concat each file into libs.js but make sure
  #     # that jQuery and Ember come first.
  #     filter Rake::Pipeline::OrderingConcatFilter, ["jquery.js", "ember.js"], "libs.js"
  #   end
  class OrderingConcatFilter < ConcatFilter

    # @param [Array<String>] ordering an Array of Strings
    #   of file names that should come in the specified order
    # @param [String] string the name of the output file to
    #   concatenate inputs to.
    # @param [Proc] block a block to use as the Filter's
    #   {#output_name_generator}.
    def initialize(ordering, string=nil, &block)
      @ordering = ordering
      super(string, &block)
    end

    # Extend the {#generate_output} method supplied by {ConcatFilter}.
    # Re-orders the inputs such that the specified files come first.
    # If a file is not in the list it will come after the specified files.
    def generate_output(inputs, output)
      @ordering.reverse.each do |name|
        file = inputs.find{|i| i.path == name }
        inputs.unshift(inputs.delete(file)) if file
      end
      super
    end
  end
end
