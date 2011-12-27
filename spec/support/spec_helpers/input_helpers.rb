class Rake::Pipeline
  module SpecHelpers
    module InputHelpers
      def input_file(path, root=File.join(tmp, "app/assets"))
        Rake::Pipeline::FileWrapper.new root, path
      end

      def output_file(path, root=File.join(tmp, "public"))
        input_file(path, root)
      end

      def create_files(files)
        Array(files).each do |file|
          mkdir_p File.dirname(file.fullpath)

          File.open(file.fullpath, "w") do |file|
            file.write "// This is #{file.path}\n"
          end
        end
      end
    end
  end
end
