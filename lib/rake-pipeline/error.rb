module Rake
  class Pipeline
    class Error < ::StandardError
    end

    class EncodingError < Error
    end

    class UnopenedFile < Error
    end
  end
end
