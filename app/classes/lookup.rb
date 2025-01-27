# frozen_string_literal: true

class Lookup
  attr_reader :model, :vals, :params

  def initialize(vals, params = {})
    @vals = prepare_vals(vals)
    @params = params
  end

  def prepare_vals(vals)
    return [] if vals.blank?

    [vals].flatten
  end

  def ids
    @ids ||= lookup_ids
  end

  def instances
    @instances ||= lookup_instances
  end

  def titles
    @titles ||= lookup_titles
  end

  def lookup_ids
    return [] if @vals.blank?

    evaluate_values_as_ids
  end

  # Could just look them up from the ids, but vals may already have instances
  def lookup_instances
    return [] if @vals.blank?

    evaluate_values_as_instances
  end

  def lookup_titles
    return [] if @vals.blank?

    instances.map(&:"#{@name_column}")
  end

  def evaluate_values_as_ids
    @vals.map do |val|
      if val.is_a?(@model)
        val.id
      elsif val.is_a?(AbstractModel)
        raise("Passed a #{val.class} to LookupIDs for #{@model}.")
      elsif /^\d+$/.match?(val.to_s)
        val
      else
        lookup_method(val).map(&:id) # each lookup returns an array
      end
    end.flatten.uniq.compact
  end

  def evaluate_values_as_instances
    @vals.map do |val|
      if val.is_a?(@model)
        val
      elsif val.is_a?(AbstractModel)
        raise("Passed a #{val.class} to LookupIDs for #{@model}.")
      elsif /^\d+$/.match?(val.to_s)
        @model.find(val.to_i)
      else
        lookup_method(val)
      end
    end.flatten.uniq.compact
  end
end
