# encoding: utf-8

# Manages the Mushroom Observer Application Programming Interface
class API
  def parse_object(key, args = {})
    declare_parameter(key, :object, args)
    str = get_param(key)
    return args[:default] unless str
    fail "missing limit!" unless args.key?(:limit)
    type, id = parse_object_type(str)
    val = find_object(str, args[:limit], type, id)
    check_edit_permission!(val, args)
    val
  end

  def parse_object_type(str)
    match = str.match(/^([a-z][ _a-z]*[a-z]) #?(\d+)$/i)
    fail BadParameterValue.new(str, :object) unless match
    [match[1].tr(" ", "_").downcase, match[2]]
  end

  def find_object(str, limit, type, id)
    val = nil
    limit.each do |model|
      next unless model.type_tag.to_s == type
      val = model.safe_find(id)
      return val if val
      fail ObjectNotFoundById.new(str, model)
    end
    fail BadLimitedParameterValue.new(str, limit.map(&:type_tag))
  end
end
