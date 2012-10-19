class Rake::Pipeline
  class GsubFilter < Filter
    def initialize(*args, &block)
      @args, @bock = args, block
      super() { |input| input }
    end

    def generate_output(inputs, output)
      inputs.each do |input|
        output.write input.read.gsub(*@args, &@block)
      end
    end
  end
end
