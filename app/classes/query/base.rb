# frozen_string_literal: true

# base class for Query searches
class Query::Base
  include ActiveModel::API
  include ActiveModel::Attributes
  include ActiveModel::Validations::Callbacks

  include Query::Modules::ClassMethods
  include Query::Modules::BoundingBox
  include Query::Modules::Conditions
  include Query::Modules::Associations
  include Query::Modules::Datetime
  include Query::Modules::GoogleSearch
  include Query::Modules::HighLevelQueries
  include Query::Modules::Initialization
  include Query::Modules::Joining
  include Query::Modules::LookupObjects
  include Query::Modules::LowLevelQueries
  include Query::Modules::Ordering
  include Query::Modules::SequenceOperators
  include Query::Modules::Sql
  include Query::Modules::Validation

  validates_with Query::Modules::Validator # , options

  # "clean up" params, store any @validation_errors,
  # and reassign attributes, restoring blank defaults, before validation
  before_validation :clean_and_validate_params

  attr_writer :record

  delegate :parameter_declarations, to: :class

  def self.parameter_declarations
    {
      join: [:string],
      tables: [:string],
      where: [:string],
      group: :string,
      order: :string,
      selects: :string,
      order_by: :string,
      title: [:string]
    }
  end

  delegate :takes_parameter?, to: :class

  def self.takes_parameter?(key)
    parameter_declarations.key?(key)
  end

  def initialize_flavor
    # These strings can never come direct from user, so no need to sanitize.
    # (I believe they are only used by the site stats page. -JPH 20190708)
    self.where += params[:where] if params[:where]
    add_join(params[:join]) if params[:join]
  end

  delegate :subquery_parameters, to: :class

  def self.subquery_parameters
    parameter_declarations.select { |key, _v| key.to_s.include?("_query") }
  end

  def scope_parameters
    self.class.scope_parameters
  end

  def self.scope_parameters
    parameter_declarations.keys.except(*subquery_parameters)
  end

  # A "current_or_related_query" may be called for links:
  # (1) for a new query on a related target model, using the current_query as
  #     the filtering subquery.
  # (2) from an index that itself was the result of a subquery.
  #     For example, if you follow links in the current UI from:
  #       [target model] of these [filtering model]
  #       Observations of these names -> (that's a plain obs query)
  #       Locations of these observations -> (location query with obs_subquery)
  #       Map of these locations -> (loc, obs_subquery)
  #       Names at these locations -> (name, obs_subquery, obs have the loc)
  #       Observations of these names -> (obs query)
  #     Note that the last index is really the original query, so to prevent
  #     recursive subquery nesting, we always want check for the currently
  #     needed (sub)query nested within the params.
  # (3) from maps to indexes of the same objects. Returns the current_query.
  #
  def relatable?(target)
    self.class.related?(target, model.name.to_sym)
  end

  def subquery_of(target)
    self.class.current_or_related_query(target, model.name.to_sym, self)
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
