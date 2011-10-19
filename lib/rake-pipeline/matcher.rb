module Rake
  class Pipeline
    class Matcher < Pipeline
      attr_accessor :input_files
      attr_reader :pattern

      def glob=(pattern)
        pattern = Regexp.escape(pattern)

        # replace \{x,y,z\} with (x|y|z)
        pattern.gsub!(/\\\{([^\}]*)\\\}/) do
          pipes = $1.split(",").join("|")
          "(#{pipes})"
        end

        # replace \*\* with .*
        pattern.gsub!("\\*\\*", ".*")

        # replace \* with [^/]*
        pattern.gsub!("\\*", "[^#{File::SEPARATOR}]*")

        # create a new anchored, insensitive regex
        @pattern = Regexp.new("#{pattern}$", "i")
      end

      def output_files
        super + input_files.reject do |file|
          file.path =~ @pattern
        end
      end

    private
      def eligible_input_files
        input_files.select do |file|
          file.path =~ @pattern
        end
      end
    end
  end
end
