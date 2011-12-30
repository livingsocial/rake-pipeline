class Rake::Pipeline
  module SpecHelpers
    class MemoryFileWrapper < Struct.new(:root, :path, :encoding, :body)
      @@files = {}

      def self.files
        @@files
      end

      def with_encoding(new_encoding)
        self.class.new(root, path, new_encoding, body)
      end

      def fullpath
        File.join(root, path)
      end

      def create
        @@files[fullpath] = self
        self.body = ""
        yield
      end

      alias read body

      def write(contents)
        self.body << contents
      end
    end
  end
end
