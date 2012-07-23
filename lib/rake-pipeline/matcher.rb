require "strscan"

module Rake
  class Pipeline
    # A Matcher is a type of pipeline that restricts its
    # filters to a particular pattern.
    #
    # A Matcher's pattern is a File glob.
    #
    # For instance, to restrict filters to operating on
    # JavaScript files in the +app+ directory, the Matcher's
    # {Pipeline#inputs inputs} should include +"app"+,
    # and its glob would be +"*.js"+.
    #
    # In general, you should not use Matcher directly. Instead use
    # {DSL#match} in the block passed to {Pipeline.build}.
    class Matcher < Pipeline
      attr_reader :glob, :pattern

      # @return [Rake::Pipeline] the Rake::Pipeline that contains
      #   this matcher.
      attr_accessor :pipeline

      # A glob matcher that a filter's input files must match
      # in order to be processed by the filter.
      #
      # @return [String]
      def glob=(pattern)
        @glob = pattern
        if pattern.kind_of?(Regexp)
          @pattern = pattern
        else
          @pattern = scan_string
        end
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

      # Override {Pipeline#finalize} to do nothing. We want to pass
      # on our unmatched inputs to the next part of the pipeline.
      #
      # @return [void]
      # @api private
      def finalize
      end

    protected
      # Let our containing pipeline generate temp directories for us.
      def generate_tmpdir
        pipeline.generate_tmpdir
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

      # Convert string to regexp using StringScanner
      #
      # @return [Regexp]
      def scan_string
        scanner = StringScanner.new(glob)

        output, pos = "", 0

        # keep scanning until end of String
        until scanner.eos?

          # look for **/, *, {...}, or the end of the string
          new_chars = scanner.scan_until %r{
              \*\*/
            | /\*\*/
            | \*
            | \{[^\}]*\}
            | $
          }x

          # get the new part of the string up to the match
          before = new_chars[0, new_chars.size - scanner.matched_size]

          # get the match and new position
          match = scanner.matched
          pos = scanner.pos

          # add any literal characters to the output
          output << Regexp.escape(before) if before

          output << case match
          when "/**/"
            # /**/ matches either a "/" followed by any number
            # of characters or a single "/"
            "(/.*|/)"
          when "**/"
            # **/ matches the beginning of the path or
            # any number of characters followed by a "/"
            "(^|.*/)"
          when "*"
            # * matches any number of non-"/" characters
            "[^/]*"
          when /\{.*\}/
            # {...} is split over "," and glued back together
            # as an or condition
            "(" + match[1...-1].gsub(",", "|") + ")"
          else String
            # otherwise, we've grabbed until the end
            match
          end
        end

        if glob.include?("/")
          # if the pattern includes a /, it must match the
          # entire input, not just the end.
          Regexp.new("^#{output}$", "i")
        else
          # anchor the pattern either at the beginning of the
          # path or at any "/" character
          Regexp.new("(^|/)#{output}$", "i")
        end
      end
    end
  end
end
