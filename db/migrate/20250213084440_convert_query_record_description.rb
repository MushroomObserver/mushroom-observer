class ConvertQueryRecordDescription < ActiveRecord::Migration[7.2]
  def up
    QueryRecord.find_each do |record|
      str = record.instance_variable_get(:@attributes)['description'].
            value_before_type_cast
      old_description = deserialize(str)
      record.description = old_description.to_json
      record.save
    end
  end

  def down
    QueryRecord.delete_all
  end

  def deserialize(str)
    params = deserialize_params(str)
    model  = params[:model]
    params.delete(:model)
  end

  def deserialize_params(str)
    params = {}
    str.split(";").each do |line|
      next if line !~ /^(\w+)=(.*)/

      key = Regexp.last_match(1)
      val = Regexp.last_match(2)
      params[key.to_sym] = deserialize_value(val)
    end
    params
  end

  def deserialize_value(val)
    val = val.sub(/^(.)/, "")
    case Regexp.last_match(1)
    when "@" then val.split(",").map { |v| deserialize_value(v) }
    when "$" then deserialize_string(val)
    when ":" then deserialize_string(val).to_sym
    when "#" then deserialize_number(val)
    when "1" then true
    when "0" then false
    when "-" then nil
    end
  end

  def deserialize_string(val)
    String.new(val).force_encoding("binary").gsub(/%(..)/) do |match|
      match[1..2].hex.chr("binary")
    end.force_encoding("UTF-8")
  end

  def deserialize_number(val)
    val.include?(".") ? val.to_f : val.to_i
  end
end
