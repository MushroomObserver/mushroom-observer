# frozen_string_literal: true

class Lookup
  attr_reader :model, :vals, :params

  def initialize(vals, params = {})
    @vals = prepare_vals(vals)
    @params = params
  end

  def prepare_vals(vals)
    return [] if vals.blank?

    if vals.is_a?(Array)
      vals
    else
      [vals]
    end
  end

  def ids
    @ids ||= lookup_ids
  end

  def instances
    @instances ||= lookup_instances
  end

  def lookup_ids
    return [] unless @vals

    @vals = [@vals] unless @vals.is_a?(Array)
    evaluate_values_as_ids
  end

  def lookup_instances
    return [] unless @vals

    @vals = [@vals] unless @vals.is_a?(Array)
    evaluate_values_as_instances
  end

  # This is checking for an instance, then sanity-checking for an instance of
  # the wrong model, then for an ID, then yielding to the lookup lambda.
  # In the last condition, `yield` means run any lambda block provided to this
  # method. (It only looks up the record in the case it can't find an ID.)
  def evaluate_values_as_ids
    @vals.map do |val|
      if val.is_a?(@model)
        val.id
      elsif val.is_a?(AbstractModel)
        raise("Passed a #{val.class} to LookupIDs for #{@model}.")
      elsif /^\d+$/.match?(val.to_s)
        val
      else # each lookup returns an array
        lookup_method(val).map(&:id)
      end
    end.flatten.uniq.compact
  end

  def evaluate_values_as_instances(&)
    @vals.map do |val|
      if val.is_a?(@model)
        val
      elsif val.is_a?(AbstractModel)
        raise("Passed a #{val.class} to LookupIDs for #{@model}.")
      elsif /^\d+$/.match?(val.to_s)
        @model.find(val.to_i)
      else # each lookup returns an array
        lookup_method(val)
      end
    end.flatten.uniq.compact
  end
end
