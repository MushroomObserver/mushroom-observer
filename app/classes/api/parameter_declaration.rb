# API
class API
  # Information about an API parameter to provide automatic documentation
  class ParameterDeclaration
    attr_accessor :key, :type, :args

    def initialize(key, type, args = {})
      self.key  = key
      self.type = type
      self.args = args
    end

    def inspect
      "#{key}: #{type} #{args.inspect}"
    end
  end
end
