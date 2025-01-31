# frozen_string_literal: true

# validation of Query parameters
module Query::Modules::Validation
  attr_accessor :params, :params_cache

  def required_parameters
    keys = parameter_declarations.keys
    keys.select! { |x| x.to_s[-1] == "?" }
    keys.sort_by(&:to_s)
  end

  def validate_params
    old_params = @params.dup
    new_params = {}
    parameter_declarations.each do |param, param_type|
      validate_param(old_params, new_params, param, param_type)
    end
    check_for_unexpected_params(old_params)
    @params = new_params
  end

  def validate_param(old_params, new_params, param_sym, param_type)
    param = param_sym.to_s.sub(/\?$/, "").to_sym
    optional = (param != param_sym)
    begin
      val = pop_param_value(old_params, param)
      val = validate_value(param_type, param, val) if val.present?
      if !val.nil?
        new_params[param] = val
      elsif !optional
        raise(
          "Missing :#{param} parameter for #{model} query."
        )
      else
        new_params[param] = nil
      end
    rescue MissingValue
      unless optional
        raise(
          "Missing :#{param} parameter for #{model} query."
        )
      end
    end
  end

  class MissingValue < RuntimeError; end

  def pop_param_value(old_params, param)
    if old_params.key?(param)
      val = old_params[param]
    elsif old_params.key?(param.to_s)
      val = old_params[param.to_s]
    else
      raise(MissingValue.new)
    end
    old_params.delete(param)
    old_params.delete(param.to_s)
    val
  end

  def check_for_unexpected_params(old_params)
    return if old_params.keys.empty?

    str = old_params.keys.map(&:to_s).join("', '")
    raise("Unexpected parameter(s) '#{str}' for #{model} query.")
  end

  def array_validate(param, val, param_type)
    case val
    when Array
      val[0, MO.query_max_array].map do |val2|
        scalar_validate(param, val2, param_type)
      end
    when ::API2::OrderedRange
      [scalar_validate(param, val.begin, param_type),
       scalar_validate(param, val.end, param_type)]
    else
      [scalar_validate(param, val, param_type)]
    end
  end

  def scalar_validate(param, val, param_type)
    if param_type.is_a?(Symbol)
      send(:"validate_#{param_type}", param, val)
    elsif param_type.is_a?(Class) &&
          param_type.respond_to?(:descends_from_active_record?)
      validate_record_or_id_or_string(param, val, param_type)
    elsif param_type.is_a?(Hash)
      validate_enum(param, val, param_type)
    else
      raise("Invalid declaration of :#{param} for #{model} " \
            "query! (invalid type: #{param_type.class.name})")
    end
  end

  def validate_enum(param, val, hash)
    if hash.keys.length != 1
      raise(
        "Invalid enum declaration for :#{param} for #{model} " \
        "query! (wrong number of keys in hash)"
      )
    end

    arg_type = hash.keys.first
    set = hash.values.first
    unless set.is_a?(Array)
      raise(
        "Invalid enum declaration for :#{param} for #{model} " \
        "query! (expected value to be an array of allowed values)"
      )
    end

    val2 = scalar_validate(param, val, arg_type)
    if (arg_type == :string) && set.include?(val2.to_sym)
      val2 = val2.to_sym
    elsif set.exclude?(val2)
      raise("Value for :#{param} should be one of the following: " \
            "#{set.inspect}.")
    end
    val2
  end

  def validate_boolean(param, val)
    case val
    # Disable cop because we do mean to symbols with boolean names
    # rubocop:disable Lint/BooleanSymbol
    when :true, :yes, :on, "true", "yes", "on", "1", 1, true
      true
    when :false, :no, :off, "false", "no", "off", "0", 0, false, nil
      false
    # rubocop:enable Lint/BooleanSymbol
    else
      raise("Value for :#{param} should be boolean, got: #{val.inspect}")
    end
  end

  def validate_integer(param, val)
    if val.is_a?(Integer) || val.is_a?(String) && val.match(/^-?\d+$/)
      val.to_i
    elsif val.blank?
      nil
    else
      raise("Value for :#{param} should be an integer, got: #{val.inspect}")
    end
  end

  def validate_float(param, val)
    if val.is_a?(Integer) || val.is_a?(Float) ||
       (val.is_a?(String) && val.match(/^-?(\d+(\.\d+)?|\.\d+)$/))
      val.to_f
    else
      raise("Value for :#{param} should be a float, got: #{val.inspect}")
    end
  end

  def validate_record_or_id_or_string(param, val, type = ActiveRecord::Base)
    if val.is_a?(type)
      raise("Value for :#{param} is an unsaved #{type} instance.") unless val.id

      # Cache the instance for later use, in case we both instantiate and
      # execute query in the same action.
      @params_cache ||= {}
      @params_cache[param] = val
      val.id
    elsif could_be_record_id?(param, val)
      val.to_i
    elsif val.is_a?(String) && param != :ids
      val
    else
      raise("Value for :#{param} should be id, string " \
            "or #{type} instance, got: #{val.inspect}")
    end
  end

  def validate_string(param, val)
    if val.is_a?(Integer) || val.is_a?(Float) ||
       val.is_a?(String) || val.is_a?(Symbol)
      val.to_s
    else
      raise("Value for :#{param} should be a string or symbol, " \
            "got a #{val.class}: #{val.inspect}")
    end
  end

  def validate_id(param, val, type = ActiveRecord::Base)
    if val.is_a?(type)
      raise("Value for :#{param} is an unsaved #{type} instance.") unless val.id

      # Cache the instance for later use, in case we both instantiate and
      # execute query in the same action.
      @params_cache ||= {}
      @params_cache[param] = val
      val.id
    elsif could_be_record_id?(param, val)
      val.to_i
    else
      raise("Value for :#{param} should be id or #{type} instance, " \
            "got: #{val.inspect}")
    end
  end

  def validate_name(param, val)
    case val
    when Name
      raise("Value for :#{param} is an unsaved Name instance.") unless val.id

      @params_cache ||= {}
      @params_cache[param] = val
      val.id
    when String, Integer
      val
    else
      raise("Value for :#{param} should be a Name, String or Integer, " \
            "got: #{val.class}")
    end
  end

  def validate_date(param, val)
    if val.acts_like?(:date)
      format("%04d-%02d-%02d", val.year, val.mon, val.day)
    elsif /^\d\d\d\d(-\d\d?){0,2}$/i.match?(val.to_s) ||
          /^\d\d?(-\d\d?)?$/i.match?(val.to_s)
      val
    elsif val.blank? || val.to_s == "0"
      nil
    else
      raise("Value for :#{param} should be a date (YYYY-MM-DD or MM-DD), " \
            "got: #{val.inspect}")
    end
  end

  def validate_time(param, val)
    if val.acts_like?(:time)
      val = val.utc
      format("%04d-%02d-%02d-%02d-%02d-%02d",
             val.year, val.mon, val.day, val.hour, val.min, val.sec)
    elsif /^\d\d\d\d(-\d\d?){0,5}$/i.match?(val.to_s)
      val
    elsif val.blank? || val.to_s == "0"
      nil
    else
      raise(
        "Value for :#{param} should be a UTC time (YYYY-MM-DD-HH-MM-SS), " \
        "got: #{val.class.name}::#{val.inspect}"
      )
    end
  end

  def validate_query(param, val)
    case val
    when Query::Base
      val.record.id
    when Integer
      val
    else
      raise(
        "Value for :#{param} should be a Query class, got: #{val.inspect}"
      )
    end
  end

  def find_cached_parameter_instance(model, param)
    @params_cache ||= {}
    @params_cache[param] ||= if could_be_record_id?(param, params[param])
                               model.find(params[param])
                             else
                               lookup_record_by_name(model, params[param])
                             end
  end

  def get_cached_parameter_instance(param)
    @params_cache ||= {}
    @params_cache[param]
  end

  def validate_value(param_type, param, val)
    if param_type.is_a?(Array)
      array_validate(param, val, param_type.first)
    else
      scalar_validate(param, val, param_type)
    end
  end

  def could_be_record_id?(param, val)
    val.is_a?(Integer) ||
      val.is_a?(String) && val.match(/^[1-9]\d*$/) ||
      # (blasted admin user has id = 0!)
      val.is_a?(String) && (val == "0") && (param == :user)
  end

  def lookup_record_by_name(type, val)
    lookup = "Lookup::#{type.name.pluralize}".constantize
    result = lookup.new(val).instances&.first
    raise("Couldn't find an id for : #{val.inspect}") unless result

    result
  end
end
