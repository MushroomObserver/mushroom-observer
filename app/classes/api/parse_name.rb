# API
class API
  def parse_name(key, args = {})
    declare_parameter(key, :name, args)
    str = get_param(key)
    return args[:default] unless str
    raise BadParameterValue.new(str, :name) if str.blank?
    val = try_parsing_id(str, Name) || find_name(str)
    if args[:correct_spelling] && val.correct_spelling
      val = val.correct_spelling
    end
    val
  end

  private

  def find_name(str)
    val = Name.where("deprecated IS FALSE
                      AND (text_name=? OR search_name=?)", str, str)
    val = Name.where("text_name=? OR search_name=?", str, str) if val.empty?
    if val.empty?
      raise NameDoesntParse.new(str) unless Name.parse_name(str)
      raise ObjectNotFoundByString.new(str, Name)
    end
    raise AmbiguousName.new(str, val) if val.length > 1
    val.first
  end
end
