# frozen_string_literal: true

##############################################################################
#
#  :module: HashValidation
#
#  Validates every Hash-shaped query_attr convention: an enum
#  (`{ string: [...] }`/`{ boolean: [true] }`), a subquery
#  (`{ subquery: :Model }`), a polymorphic record
#  (`{ polymorphic: [Model, ...] }`), or a plain set of named fields.
#  Query::Modules::Validation handles scalar and array param
#  validation instead. `validate_hash_param` is the dispatch point,
#  called from Query::Modules::Validation#scalar_validate.
#
module Query::Modules::HashValidation
  private

  def validate_hash_param(param, val, param_type)
    if [:string, :boolean].include?(param_type.keys.first)
      validate_enum(param, val, param_type)
    elsif param_type.keys.first == :subquery
      validate_subquery(param, val, param_type)
    elsif param_type.keys.first == :polymorphic
      validate_polymorphic(param, val, param_type)
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
      return add_validation_error(:query_validation_invalid_subquery,
                                  param: param.to_s, model:)
    end
    submodel = param_type.values.first
    subquery = Query.create_query(submodel, val)
    @subqueries[param] = subquery
    @validation_errors += subquery.validation_errors
    subquery.params
  end

  def validate_enum(param, val, hash)
    if hash.keys.length != 1
      return add_validation_error(:query_validation_invalid_enum_keys,
                                  param: param.to_s, model:)
    end

    arg_type = hash.keys.first
    set = hash.values.first
    unless set.is_a?(Array)
      return add_validation_error(:query_validation_invalid_enum_not_array,
                                  param: param.to_s, model:)
    end

    validate_enum_value(param, val, arg_type, set)
  end

  def validate_enum_value(param, val, arg_type, set)
    val2 = scalar_validate(param, val, arg_type)
    if (arg_type == :string) && set.include?(val2.to_s.to_sym)
      val2.to_s.to_sym
    elsif set.exclude?(val2)
      add_validation_error(:query_validation_param_not_in_set,
                           param: param.to_s, set: set.inspect)
    else
      val2
    end
  end

  # A polymorphic record filter. Accepts a `{ type:, id: }` hash, the
  # shape an index filter param sends (e.g. Comment#target merging
  # `params[:type]`/`params[:target]`). Also accepts a live instance
  # of one of `param_type`'s allowed classes, for a Ruby caller
  # building the query directly. Either way, resolves to the
  # `{ type:, id: }` hash of primitives Query persists. Verifies the
  # type is one of the declared classes and the id exists, so callers
  # don't have to duplicate that lookup.
  def validate_polymorphic(param, val, param_type)
    types = param_type.values.first
    return validate_polymorphic_instance(param, val, types) if
      val.is_a?(AbstractModel)

    validate_polymorphic_hash(param, val, types)
  end

  def validate_polymorphic_instance(param, val, types)
    unless types.include?(val.class)
      add_validation_error(:query_validation_invalid_polymorphic_type,
                           param: param.to_s, type: val.class.name)
      return invalid_polymorphic_value
    end
    return valid_polymorphic_record(val) if val.id

    add_validation_error(:query_validation_record_unsaved,
                         param: param.to_s, type: val.class)
    invalid_polymorphic_value
  end

  def validate_polymorphic_hash(param, val, types)
    model = resolve_polymorphic_type(param, val, types)
    return invalid_polymorphic_value unless model

    record = resolve_polymorphic_record(param, val, model)
    return invalid_polymorphic_value unless record

    valid_polymorphic_record(record)
  end

  def resolve_polymorphic_type(param, val, types)
    type_name = val.is_a?(Hash) ? val[:type].to_s : val.inspect
    model = types.find { |t| t.name == type_name }
    return model if model

    add_validation_error(:query_validation_invalid_polymorphic_type,
                         param: param.to_s, type: type_name)
    nil
  end

  def resolve_polymorphic_record(param, val, model)
    record = model.safe_find(val[:id])
    return record if record

    add_validation_error(:query_validation_polymorphic_not_found,
                         param: param.to_s, type: model.type_tag,
                         id: val[:id].inspect)
    nil
  end

  def valid_polymorphic_record(record)
    { type: record.class.name, id: record.id }
  end

  # A validation failure still has to leave the attr present.
  # Otherwise Query::Modules::Initialization's skippable_values treats
  # it as absent and skips the scope entirely, leaving the query
  # unfiltered instead of empty. `Comment.target`'s own `type && id`
  # guard turns this into `none`. FilterCaption's
  # `lookup_comment_target_val` bails out on a blank type/id instead
  # of trying to `constantize` a type string with no backing class.
  def invalid_polymorphic_value
    { type: nil, id: nil }
  end
end
