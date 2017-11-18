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
      "#{key}: #{show_type}#{show_args}"
    end

    def show_type
      val = type.to_s
      val += " range" if args[:range]
      val += " list"  if args[:list]
      val
    end

    def show_args
      hash = args.except(:as, :list, :range)
      hash.delete(:default) if hash[:default].to_s == ""
      hash[:limit] = "#{hash[:limit]} chars" if hash[:limit].to_s =~ /^\d+$/
      return "" if hash.empty?
      " (" + hash.map { |key, val| show_arg(key, val) }.join(", ") + ")"
    end

    def show_arg(key, val)
      if key == :help
        val = @key if val == 1
        tag = "api_help_#{val}".to_sym
        tag.l
      elsif key != :limit && val == true
        key.to_s
      else
        "#{key}=#{show_val(val)}"
      end
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def show_val(val)
      case val
      when String, Symbol, Integer, Float, Range
        val.to_s
      when Array
        val.map(&:to_s).join("|")
      when TrueClass
        "true"
      when FalseClass
        "false"
      when Date
        val.api_date
      when Time
        val.api_time
      when License
        val.display_name
      when Name
        val.search_name
      when User
        val.login
      else
        raise "Don't know how to display #{val.class.name} in api help msg."
      end
    end
  end
end
