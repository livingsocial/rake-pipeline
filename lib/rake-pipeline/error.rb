module Rake
  class Pipeline
    # The general Rake::Pipeline error class
    class Error < ::StandardError
    end

    # The error that Rake::Pipeline uses when it detects
    # that a file uses an improper encoding.
    class EncodingError < Error
    end

    # The error that Rake::Pipeline uses if you try to
    # write to a FileWrapper before creating it.
    class UnopenedFile < Error
    end
  end
end
