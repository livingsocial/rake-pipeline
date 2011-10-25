module Rake
  class Pipeline
    # A Matcher is a type of pipeline that restricts its
    # filters to a particular pattern.
    #
    # A Matcher's pattern is a File glob.
    #
    # For instance, to restrict filters to operating on
    # JavaScript files in the +app+ directory, the Matcher's
    # {Pipeline#input_root input_root} should be +"app"+,
    # and its glob would be +"*.js"+.
    #
    # Internally, Matcher uses +File.fnmatch+ to do its
    # matching.
    #
    # In general, you should not use Matcher directly. Instead use
    # {DSL#match} in the block passed to {Pipeline.build}.
    class Matcher < Pipeline
      attr_reader :glob

      # A glob matcher that a filter's input files must match
      # in order to be processed by the filter.
      #
      # @return [String]
      def glob=(pattern)
        pattern = Regexp.escape(pattern)

        # replace \{x,y,z\} with (x|y|z)
        pattern.gsub!(/\\\{([^\}]*)\\\}/) do
          pipes = $1.split(",").join("|")
          "(#{pipes})"
        end

        # replace \*\* with .*
        pattern.gsub!(%r{\\\*\\\*/?}, ".*")

        # replace \* with [^/]*
        pattern.gsub!("\\*", "[^#{File::SEPARATOR}]*")

        # create a new anchored, insensitive regex
        @pattern = Regexp.new("#{pattern}$", "i")
      end

      # A list of the output files that invoking this pipeline will
      # generate. This will include the outputs of files matching
      # the {#glob glob} and any inputs that did not match the
      # glob.
      #
      # This will make those inputs available to any additional
      # filters or matchers.
      #
      # @return [Array<FileWrapper>]
      def output_files
        super + input_files.reject do |file|
          file.path =~ @pattern
        end
      end

    private
      # Override the default {Pipeline#eligible_input_files}
      # to include only files that match the {#glob glob}.
      #
      # @return [Array<FileWrapper>]
      def eligible_input_files
        input_files.select do |file|
          file.path =~ @pattern
        end
      end
    end
  end
end
