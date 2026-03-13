# frozen_string_literal: true

# Lookup
#
# A flexible looker-upper of records. It can handle any identifiers we're likely
# to throw at it: a string, ID, instance, or a mixed array of any of those. The
# `lookup_method` has to be configured in the Lookup child class, because the
# lookup column names are different for each model.
#
# Primarily used to get a clean set of ids for ActiveRecord query params.
# For example, indexes like "Observations for (given) Projects" can be filtered
# for more than one project at a time: "NEMF 2023" and "NEMF 2024".
# The observation query needs the project IDs, and Lookup just allows callers
# to send whatever param type is available. This is handy in the API and
# in searches.
#
# Create an instance of a child class with a string, instance or id, or a mixed
# array of any of these. Returns an array of ids, instances or strings (names)
# via instance methods `ids`, `instances` and `titles`.
#
# Use:
#   project_ids = Lookup::Projects.new(["NEMF 2023", "NEMF 2024"]).ids
#   Observation.where(project: project_ids)
#
#   fred_ids = Lookup::Users.new(["Fred", "Freddie", "Freda", "Anni Frid"]).ids
#   Image.where(user: fred_ids)
#
# Instance methods:
#   (all return arrays)
#
# ids:        Array of ids of records matching the values sent to the instance
# instances:  Array of instances of those records
# titles:     Array of names of those records, via @title_column set in subclass
#             (A `names` method seemed too confusing, because Lookup::Names...)
#
# Class constants:
#   (defined in subclass)
#
# MODEL:
# TITLE_METHOD:
#
class Lookup
  attr_reader :vals, :params

  def initialize(vals, params = {})
    unless defined?(self.class::MODEL)
      raise("Lookup is only usable via the subclasses, like Lookup::Names.")
    end

    @model = self.class::MODEL
    @title_method = self.class::TITLE_METHOD
    @vals = prepare_vals(vals)
    @params = params
  end

  def prepare_vals(vals)
    return [] if vals.blank?

    # Multiple vals may come from autocompleters as a single multiline string
    vals = vals.split("\n").compact_blank if vals.is_a?(String)
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

    instances.map(&:"#{@title_method}")
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
