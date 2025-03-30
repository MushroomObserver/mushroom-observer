# frozen_string_literal: true

# base class for Query searches
class Query::BaseAM
  include ActiveModel::API
  include ActiveModel::Attributes
  include ActiveModel::Validations::Callbacks

  include Query::Modules::ClassMethods
  include Query::ScopeModules::HighLevelQueries
  include Query::ScopeModules::Initialization
  include Query::ScopeModules::SequenceOperators
  include Query::Modules::Validation

  validates_with Query::ScopeModules::Validator # , options

  # "clean up" and reassign attributes before validation
  before_validation :pre_clean_params

  # attr_accessor :params, :params_cache, :subqueries
  attr_reader :validation_errors
  attr_writer :record

  def pre_clean_params
    validate_params
    assign_attributes(**@params)
  end

  def self.parameter_declarations
    { order_by: :string }
  end

  delegate :parameter_declarations, to: :class

  def self.takes_parameter?(key)
    parameter_declarations.key?(key)
  end

  delegate :takes_parameter?, to: :class

  def self.scope_parameters
    excepts = [:id_in_set, :preference_filter]
    @scope_parameters = parameter_declarations.except(*excepts).keys +
                        [:id_in_set]
  end

  delegate :scope_parameters, to: :class

  def self.content_filter_parameters
    filters = Query::Filter.all
    @content_filter_parameters ||= filters.each_with_object({}) do |f, p|
      p[f.sym] = f.type
    end.freeze
  end

  delegate :content_filter_parameters, to: :class

  # Can the current class be called as a subquery of the target Query class?
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

  # NOTE: QueryRecord[:description] is not a Rails-serialized column; we call
  # `to_json` here to serializate it ourselves.
  # Prepares the query params, adding the model, for saving to a QueryRecord.
  # The :description column is accessed not just to recompose a query, but to
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
