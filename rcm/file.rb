module RCM
  # Managing files
  class File
    attr_reader :path

    def initialize(path)
      @path = path
    end

    def content(content = nil)
      content.nil? ? @content : @content = content
    end

    def to_s
      @path
    end

    def do!
      puts "Evaluating #{self.class}:#{self}"
    end
  end

  # Add file keyword to the DSL
  class RCM
    def file(path, &block)
      return unless @conds_met

      f = File.new(path)
      f.instance_eval(&block)
      self << f
    end
  end
end
