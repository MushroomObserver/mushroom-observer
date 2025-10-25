# frozen_string_literal: true

##############################################################################
#
#  :module: Validation
#
#  This validator is recursive, because some params accept arrays or hashes of
#  values. Each value is ultimately validated separately, via methods below
#  that are specific to a data type. In the case of subqueries, the whole
#  package of values is sent to a new Query instantiation which returns its own
#  validation_errors. These are added to this query's messages.
#
#  Each validation method here may first "clean" the value, e.g. substituting
#  ids for instances. Generally validators do not change data, but we do here
#  to offer callers the convenience of passing instances rather than ids.
#
#  In the event it gets data that it cannot parse, it stores a message in the
#  array of `@validation_errors`, and saves that to the Query. Callers can
#  access these messages to return them via flash to users, for example when
#  the query comes from a form.
#
#  == Instance methods:
#
#  clean_and_validate_params::  Described above.
#
#  Private methods described below.
#
module Query::Modules::Validation # rubocop:disable Metrics/ModuleLength
  attr_accessor :params, :params_cache, :subqueries, :valid, :validation_errors

  def clean_and_validate_params
    @validation_errors = []
    old_params = @params.dup&.deep_compact&.deep_symbolize_keys || {}
    new_params = {}
    permitted_params = attribute_types.slice(*old_params.keys)
    permitted_params.each do |param, param_type|
      val = old_params[param]
      val = validate_value(param_type.accepts, param, val) if val.present?
      new_params[param] = val
    end
    @params = new_params
    assign_attributes(**@params) if @params.present?
  end

  private

  def validate_value(param_type, param, val)
    if param_type.is_a?(Array)
      result = array_validate(param, val, param_type.first).flatten
      result = result.uniq if positive_integers?(result)
      result
    else
      val = scalar_validate(param, val, param_type)
      [val].flatten.first
    end
  end

  def positive_integers?(list)
    list.all? { |item| item.is_a?(Integer) && item.positive? }
  end

  def array_validate(param, val, param_type)
    case val
    when Array
      val[0, MO.query_max_array].map! do |val2|
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
    case param_type
    when Symbol
      send(:"validate_#{param_type}", param, val)
    when Class
      validate_class_param(param, val, param_type)
    when Hash
      validate_hash_param(param, val, param_type)
    else
      @validation_errors <<
        "Invalid declaration of :#{param} for #{model} " \
        "query! (invalid type: #{param_type.class.name})"
      nil
    end
  end

  def validate_class_param(param, val, param_type)
    if param_type.respond_to?(:descends_from_active_record?)
      validate_record(param, val, param_type)
    else
      @validation_errors <<
        "Don't know how to parse #{param_type} :#{param} for #{model} query."
      nil
    end
  end

  def validate_hash_param(param, val, param_type)
    if [:string, :boolean].include?(param_type.keys.first)
      validate_enum(param, val, param_type)
    elsif param_type.keys.first == :subquery
      validate_subquery(param, val, param_type)
    else
      validate_nested_params(param, val, param_type)
    end
  end

  # For results, don't compact_blank, because sometimes we want `false`
  def validate_nested_params(_param, val, param_type)
    val2 = {}
    param_type.each do |key, arg_type|
      val2[key] = validate_value(arg_type, key, val[key])
    end
    val2.compact
  end

  # Validate the subquery's params by creating another Query instance
  # and save it in @subqueries to facilitate access
  def validate_subquery(param, val, param_type)
    if param_type.keys.length != 1
      @validation_errors <<
        "Invalid subquery declaration for :#{param} for #{model} " \
        "query! (wrong number of keys in hash)"
      return nil
    end
    submodel = param_type.values.first
    subquery = Query.create_query(submodel, val)
    @subqueries[param] = subquery
    @validation_errors += subquery.validation_errors
    subquery.params
  end

  def validate_enum(param, val, hash)
    if hash.keys.length != 1
      @validation_errors <<
        "Invalid enum declaration for :#{param} for #{model} " \
        "query! (wrong number of keys in hash)"
      return nil
    end

    arg_type = hash.keys.first
    set = hash.values.first
    unless set.is_a?(Array)
      @validation_errors <<
        "Invalid enum declaration for :#{param} for #{model} " \
        "query! (expected value to be an array of allowed values)"
      return nil
    end

    val2 = scalar_validate(param, val, arg_type)
    if (arg_type == :string) && set.include?(val2.to_s.to_sym)
      val2 = val2.to_s.to_sym
    elsif set.exclude?(val2)
      @validation_errors <<
        :query_validation_param_not_in_set.t(param:, set: set.inspect)
      val2 = nil
    end
    val2
  end

  # Disable cop because we do mean to symbols with boolean names
  # rubocop:disable Lint/BooleanSymbol
  def validate_boolean(param, val)
    case val
    when :true, :yes, :on, "true", "yes", "on", "1", 1, true
      true
    when :false, :no, :off, "false", "no", "off", "0", 0, false
      false
    when nil
      nil
    else
      @validation_errors << :query_validation_boolean.t(param:, val:)
      nil
    end
  end
  # rubocop:enable Lint/BooleanSymbol

  # We don't currently have params for integers, but this would enable them.
  # def validate_integer(param, val)
  #   if val.is_a?(Integer) || val.is_a?(String) && val.match(/^-?\d+$/)
  #     val.to_i
  #   elsif val.blank?
  #     nil
  #   else
  #     @validation_errors <<
  #       "Value for :#{param} should be an integer, got: #{val.inspect}")
  #   end
  # end

  def validate_float(param, val)
    if val.is_a?(Numeric) ||
       (val.is_a?(String) && val.match(/^-?(\d+(\.\d+)?|\.\d+)$/))
      val.to_f
    else
      @validation_errors << :query_validation_float.t(param:, val: val.inspect)
      nil
    end
  end

  # This type of param accepts instances, ids, or strings. When the query is
  # executed, the string will be sent to the appropriate `Lookup` subclass.
  def validate_record(param, val, type = ActiveRecord::Base)
    if val.is_a?(type)
      unless val.id
        @validation_errors << :query_validation_record_unsaved.t(param:, type:)
        return nil
      end

      set_cached_parameter_instance(param, val)
      val.id
    elsif could_be_record_id?(param, val)
      val.to_i
    elsif val.is_a?(String)
      validate_string_for_record(param, val, type)
    else
      @validation_errors <<
        :query_validation_record.t(param:, type:, val: val.inspect)
      nil
    end
  end

  def validate_string_for_record(param, val, type)
    return val unless param == :id_in_set

    @validation_errors << :query_validation_id_in_set.t(type:, val:)
    nil
  end

  def validate_string(param, val)
    if val.is_any?(Integer, Float, String, Symbol)
      val.to_s
    else
      @validation_errors <<
        :query_validation_string.t(param:, class: val.class, val: val.inspect)
      nil
    end
  end

  def validate_date(param, val)
    if val.blank? || val.to_s == "0"
      nil
    elsif val.acts_like?(:date)
      format_date(val)
    elsif /^\d\d\d\d(-\d\d?){0,2}$/i.match?(val.to_s) ||
          /^\d\d?(-\d\d?)?$/i.match?(val.to_s)
      val
    elsif (val2 = parse_date(val)).acts_like?(:date)
      format_date(val2)
    else
      @validation_errors << :query_validation_date.t(param:, val:)
      nil
    end
  end

  def parse_date(val)
    Date.parse(val)
  rescue Date::Error
    nil
  end

  def format_date(val)
    format("%04d-%02d-%02d", val.year, val.mon, val.day)
  end

  def validate_time(param, val)
    if val.blank? || val.to_s == "0"
      nil
    elsif val.acts_like?(:time)
      format_time(val)
    elsif /^\d\d\d\d(-\d\d?){0,5}$/i.match?(val.to_s)
      val
    elsif (val2 = parse_time(val)).acts_like?(:time)
      format_time(val2)
    else
      @validation_errors <<
        :query_validation_time.t(param:, class: val.class.name, val:)
      nil
    end
  end

  def parse_time(val)
    DateTime.parse(val)
  rescue ArgumentError
    nil
  end

  def format_time(val)
    format("%04d-%02d-%02d-%02d-%02d-%02d",
           val.year, val.mon, val.day, val.hour, val.min, val.sec)
  end

  def find_cached_parameter_instance(model, param)
    return @params_cache[param] if @params_cache && @params_cache[param]

    val = params[param]
    instance = if could_be_record_id?(param, val)
                 model.find(val)
               elsif val.present?
                 lookup_record_by_name(param, val, model)
               end
    set_cached_parameter_instance(param, instance)
  end

  # Cache the instance for later use, in case we both instantiate and
  # execute query in the same action.
  def set_cached_parameter_instance(param, instance)
    @params_cache ||= {}
    @params_cache[param] = instance
  end

  def could_be_record_id?(param, val)
    val.is_a?(Integer) ||
      val.is_a?(String) && val.match(/^[1-9]\d*$/) ||
      # (blasted admin user has id = 0!)
      val.is_a?(String) && (val == "0") && (param == :user)
  end

  # Requires a unique identifying string and will return [only_one_record].
  def lookup_record_by_name(param, val, type, **args)
    method = args[:method] || :instances
    lookup = lookup_class(param, val, type)

    results = lookup.new(val).send(method)
    unless results
      @validation_errors << :query_validation_lookup_id.t(val: val.inspect)
    end

    results.first
  end

  def lookup_class(param, val, type)
    # We're only validating the projects passed as the param.
    # Projects' species_lists will be looked up later.
    type = type.name.pluralize
    lookup = if param == :project_lists
               Lookup::Projects
             else
               "Lookup::#{type}".constantize
             end
    unless defined?(lookup)
      @validation_errors <<
        :query_validation_lookup.t(type:, val: val.inspect)
    end
    lookup
  end
end
