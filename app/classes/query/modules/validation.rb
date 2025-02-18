# frozen_string_literal: true

# Validation of Query parameters.
# Also adds user content filters to params if applicable. Maybe a confusion of
# concerns, but it's the only place where we instantiate the subquery.
module Query::Modules::Validation # rubocop:disable Metrics/ModuleLength
  attr_accessor :params, :params_cache

  def validate_params
    @preference_filter_applied = false
    old_params = @params.dup&.compact&.symbolize_keys || {}
    new_params = {}
    permitted_params = parameter_declarations.slice(*old_params.keys)
    permitted_params.each do |param, param_type|
      val = old_params[param]
      val = validate_value(param_type, param, val) if val.present?
      new_params[param] = val
    end
    check_for_unexpected_params(old_params)
    @params = new_params
    # Runs after validation to check if filters should be overridden by params.
    # NOTE: this is also run on each subquery during validation, below.
    apply_preference_filters(self)
    # NOTE: This param is needed to distinguish between filtering by
    # user.content_filter vs advanced search, because they use the same params.
    @params[:preference_filter] = true if @preference_filter_applied
  end

  def check_for_unexpected_params(old_params)
    unexpected_params = old_params.except(*parameter_declarations.keys)
    return if unexpected_params.keys.empty?

    str = unexpected_params.keys.map(&:to_s).join("', '")
    raise("Unexpected parameter(s) '#{str}' for #{model} query.")
  end

  # Subqueries also call this in validate_subquery for efficiency: we have
  # them briefly as a Query object and can check class param_declarations.
  def apply_preference_filters(query)
    filters = users_preference_filters || {}
    # disable cop because Query::Filter is not an ActiveRecord model
    Query::Filter.all.each do |fltr| # rubocop:disable Rails/FindEach
      apply_one_preference_filter(fltr, query, filters[fltr.sym])
    end
  end

  def apply_one_preference_filter(fltr, query, user_filter)
    return unless query.is_a?(Query::Base)

    key = fltr.sym
    return unless query.takes_parameter?(key)
    return if query.params.key?(key)
    return unless fltr.on?(user_filter)

    query.params[key] = validate_value(fltr.type, fltr.sym, user_filter.to_s)
    @preference_filter_applied = true
  end

  def users_preference_filters
    User.current ? User.current.content_filter : MO.default_content_filter
  end

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
      raise("Invalid declaration of :#{param} for #{model} " \
            "query! (invalid type: #{param_type.class.name})")
    end
  end

  def validate_class_param(param, val, param_type)
    if param_type.respond_to?(:descends_from_active_record?)
      validate_record(param, val, param_type)
    else
      raise(
        "Don't know how to parse #{param_type} :#{param} for #{model} query."
      )
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

  def validate_nested_params(_param, val, param_type)
    val2 = {}
    param_type.each do |key, arg_type|
      val2[key] = scalar_validate(key, val[key], arg_type)
    end
    val2
  end

  def validate_subquery(param, val, param_type)
    if param_type.keys.length != 1
      raise(
        "Invalid enum declaration for :#{param} for #{model} " \
        "query! (wrong number of keys in hash)"
      )
    end
    submodel = param_type.values.first
    val = add_default_subquery_conditions(submodel, val)
    subquery = Query.new(submodel, val)
    apply_preference_filters(subquery)
    subquery.params
  end

  def add_default_subquery_conditions(submodel, val)
    return val unless needs_is_collection_location_param(submodel, val)

    val.merge(is_collection_location: true)
  end

  def needs_is_collection_location_param(submodel, val)
    model == Location && submodel == :Observation &&
      (val[:project] || val[:species_list]) &&
      val[:is_collection_location].blank?
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

  # def validate_integer(param, val)
  #   if val.is_a?(Integer) || val.is_a?(String) && val.match(/^-?\d+$/)
  #     val.to_i
  #   elsif val.blank?
  #     nil
  #   else
  #     raise("Value for :#{param} should be an integer, got: #{val.inspect}")
  #   end
  # end

  def validate_float(param, val)
    if val.is_a?(Integer) || val.is_a?(Float) ||
       (val.is_a?(String) && val.match(/^-?(\d+(\.\d+)?|\.\d+)$/))
      val.to_f
    else
      raise("Value for :#{param} should be a float, got: #{val.inspect}")
    end
  end

  # This type of param accepts instances, ids, or strings. When the query is
  # executed, the string will be sent to the appropriate `Lookup` subclass.
  def validate_record(param, val, type = ActiveRecord::Base)
    if val.is_a?(type)
      raise("Value for :#{param} is an unsaved #{type} instance.") unless val.id

      set_cached_parameter_instance(param, val)
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
    if val.is_any?(Integer, Float, String, Symbol)
      val.to_s
    else
      raise("Value for :#{param} should be a string or symbol, " \
            "got a #{val.class}: #{val.inspect}")
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
    val = if could_be_record_id?(param, params[param])
            model.find(params[param])
          else
            lookup_record_by_name(param, params[param], model)
          end
    set_cached_parameter_instance(param, val)
  end

  # Cache the instance for later use, in case we both instantiate and
  # execute query in the same action.
  def set_cached_parameter_instance(param, val)
    @params_cache ||= {}
    @params_cache[param] = val
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
    raise("Couldn't find an id for : #{val.inspect}") unless results

    results.first
  end

  def lookup_class(param, val, type)
    # We're only validating the projects passed as the param.
    # Projects' species_lists will be looked up later.
    lookup = if param == :project_lists
               Lookup::Projects
             else
               "Lookup::#{type.name.pluralize}".constantize
             end
    raise("#{lookup} not defined for : #{val.inspect}") unless defined?(lookup)

    lookup
  end
end
