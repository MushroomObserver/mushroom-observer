# frozen_string_literal: true

# base class for Query searches
class Query::BaseAR
  include Query::Modules::ClassMethods
  # include Query::Modules::BoundingBox
  # include Query::Modules::Conditions
  # include Query::Modules::Associations
  # include Query::Modules::Datetime
  # include Query::Modules::GoogleSearch
  include Query::ScopeModules::HighLevelQueries
  include Query::ScopeModules::Initialization
  include Query::ScopeModules::Joining
  # include Query::Modules::LookupObjects
  include Query::ScopeModules::LowLevelQueries
  include Query::ScopeModules::Ordering
  include Query::Modules::SequenceOperators
  # include Query::Modules::Sql
  # include Query::Modules::Titles
  include Query::Modules::Validation

  attr_writer :record

  def parameter_declarations
    self.class.parameter_declarations
  end

  def self.parameter_declarations
    {
      # join: [:string],
      # tables: [:string],
      # where: [:string],
      # group: :string,
      # order: :string,
      # selects: :string,
      by: :string
      # title: [:string]
    }
  end

  def takes_parameter?(key)
    self.class.takes_parameter?(key)
  end

  def self.takes_parameter?(key)
    parameter_declarations.key?(key)
  end

  def initialize_flavor
    # These strings can never come direct from user, so no need to sanitize.
    # (I believe they are only used by the site stats page. -JPH 20190708)
    self.where += params[:where] if params[:where]
    add_join(params[:join]) if params[:join]
    initialize_parameter_set
    initialize_subquery_parameters
  end

  def initialize_parameter_set
    scope_parameters.each do |param|
      next if (param == :ids_in_set && params[param].nil?) ||
              (param != :ids_in_set && params[param].blank?)

      @scopes = @scopes.send(param, params[param])
    end
  end

  # Need to add what joins to do on the parameter_declarations
  def initialize_subquery_parameters
    subquery_parameters.each do |param, definition|
      next if params[param].blank?

      model_name = definition[:subquery]
      joins = definition[:joins]
      subquery = Query.new(model_name, params[param]).query

      @scopes = @scopes.joins(joins).merge(subquery)
    end
  end

  def subquery_parameters
    self.class.subquery_parameters
  end

  def self.subquery_parameters
    parameter_declarations.select { |key, _v| key.to_s.include?("_query") }
  end

  def scope_parameters
    self.class.scope_parameters
  end

  def self.scope_parameters
    parameter_declarations.except(*subquery_parameters).except(:by)
  end

  def default_order
    self.class.default_order ||
      raise("Didn't supply default order for #{model} query.")
  end

  def ==(other)
    serialize == other.try(&:serialize)
  end

  # NOTE: QueryRecord[:description] is not a serialized column; we call
  # `to_json` here for serialization.
  # Prepare the query params, adding the model, for saving to the db. The
  # :description column is accessed not just to recompose a query, but to
  # identify existing query records that match current params. That's why the
  # keys are sorted here before being stored as strings in to_json - because
  # when matching a serialized hash, strings must match exactly. This is
  # more efficient however than using a Rails-serialized column and comparing
  # the parsed hashes (in whatever order), because when a column is serialized
  # you can't use SQL on the column value, you have to compare parsed instances.
  def serialize
    params.sort.to_h.merge(model: model.name).to_json
  end

  def record
    # This errors out if @record is not set since it
    # cannot find Query.get_record.  If you copy the
    # above definition of get_record into the same scope
    # as this method and get rid of "Query." it works,
    # but that is not a great solution.
    # You can trigger the issue which is
    # triggered if the :wolf_fart observation has
    # second image.  See query_test.rb for more.
    @record ||= self.class.get_record(self)
  end

  delegate :id, to: :record

  delegate :save, to: :record

  def increment_access_count
    record.access_count += 1
  end
end
