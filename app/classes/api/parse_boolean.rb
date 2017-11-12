# API
class API
  def parse_boolean(key, args = {})
    declare_parameter(key, :boolean, args)
    str = get_param(key)
    return args[:default] unless str
    val = positive?(str)
    limit = args[:limit]
    raise BadLimitedParameterValue.new(str, [limit]) if limit && val != limit
    val
  end

  private

  def positive?(str)
    case str.downcase
    when "1", "yes", "true", :yes.l then true
    when "0", "no", "false", :no.l then false
    else
      raise BadParameterValue.new(str, :boolean)
    end
  end
end
