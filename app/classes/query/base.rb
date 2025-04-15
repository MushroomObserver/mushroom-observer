# frozen_string_literal: true

#  CREATING A NEW QUERY SUBCLASS
#
#  To make an ActiveRecord model queryable, create a new class that inherits
#  from this class, Query::Base.
#
#  ## OVERVIEW
#
#  Query is basically just a way to validate, sanitize, store and retrieve
#  parameters that filter a database query of a given model, like `Name` or
#  `Observation`. A Query instance contains as little data as possible; it does
#  not contain AR records. When you execute the Query by calling the `results`
#  method, each parameter of the Query instance gets sent to an ActiveRecord
#  scope of the corresponding model, and the scope returns the results. Query
#  parameters are therefore specific to each scope of the AR model.
#
#  Each Query class declares the parameters it will accept, and what type of
#  data each parameter expects, in `parameter_declarations` at the top of the
#  class. These are the `attributes` you initialize a new Query instance with.
#
#    Query::Observations.new(           or     Query.new(:Observation,
#      has_public_lat_lng: true,                 has_public_lat_lng: true,
#      region: "Massachusetts, USA",             region: "Massachusetts, USA",
#      names: { lookup: "Amanita" }              names: { lookup: "Amanita" }
#    )                                         )
#  * (see note below)
#
#  ## VALIDATION
#
#  For the sake of familiarity, Query classes use ActiveModel. Each instance of
#  a Query class is a data object with validatable attributes, instance methods
#  and class methods. The methods are all pretty standard. They are defined
#  either here in Query::Base, or in one of the included Query::Modules.
#
#  The main difference from ActiveRecord objects (that also use ActiveModel) is
#  attribute validation. ActiveRecord attributes must have data types that can
#  be validated and stored in a database. _ActiveModel_ attributes are "ad hoc"
#  and temporary. Because they don't need to be stored in a database they can
#  have any data type. They only need to "work" for the use case — a form, a
#  query, etc. But we can call the same `validate` patterns as on AR models.
#
#  In our case, we define our own validator and data type. That data type is
#  `query_param`, and the attribute values are both checked and sanitized by
#  Query::Modules::Validation on initialization. Calling `valid?` uses
#  Query::Modules::Validator to check for any validation errors that may
#  have been stored in the Query instance by `clean_and_validate_params`.
#
#  So, `valid?` should mean the parameter values are usable by the corresponding
#  ActiveRecord scope in each model. The scopes are what actually execute the
#  database query and define the parameter requirements.
#
#  * Potential gotcha: Most query attributes, like `has_public_lat_lng` for
#    Observation, are declared in the Query class, e.g. Query::Observations.
#    However, for certain params like `region`, they are declared in
#    Query::Filter. These are handled differently, because default values for
#    these params may be automatically passed in from the current user's
#    preferences via methods in ApplicationController::Indexes.
#
#  ## PARAMETER DECLARATIONS
#
#  Query parameter names must map to AR scope names 1:1 (with few exceptions).
#  So the first task is to write a scope for the model that does what you want.
#
#  For example, in the query above, the parameter `has_public_lat_lng` is first
#  a scope of our Observation model that accepts a Boolean value. It finds
#  observations that both have a `lat` value and where `gps_hidden` is false.
#  `region` is a scope of Observation that accepts a string, and finds
#  observations within a given region. The scope `names` finds observations in
#  given taxa. It accepts a hash of arguments, with `lookup` being required.
#  But all of these requirements and logic are ultimately defined in the scope;
#  Query is simply there to gather and store them, and pass them along.
#
#  Since the scopes can only accept certain types of data, Query needs to
#  validate (and sometimes "clean") the attributes passed to the Query instance.
#  Even though `query_param` is a single declared data type, it actually is
#  the `parameter_declarations` that give the information about the way the
#  attribute is validated. (My plan was to add that as an arg to each
#  `query_param` and have a validator automatically parse the declared arg for
#  all `query_param`s, but i couldn't figure out how to do this.)
#
#  We use a special syntax to declare the data type of each Query parameter /
#  attribute. The syntax is important because it tells our validation method in
#  Query::Modules::Validation, `clean_and_validate_params`, how to parse the
#  attribute value.
#
#  ### Simple
#
#  The simplest data types are pretty self explanatory:
#
#    :string
#    :float
#    :date
#    :time
#    :boolean
#
#  Note that with some parameters, a `:string` may be a "Google-search" syntax
#  of search directives like 'Amanita -muscaria "odd coloring"', but Query
#  doesn't handle any parsing of the string. It simply forwards the string to
#  the scope of the same name. The parsing is all done by the scope.
#
#  ### Model
#
#  An attribute declared with an ActiveRecord class name means that the
#  parameter will accept either an `id` or an ActiveRecord model instance.
#  If the caller sends an instance, it will be "sanitized" to an `id`, and
#  the Query instance will only save the `id`.
#
#    User
#    Location
#    Project
#
#  ### Array
#
#  An attribute declared with an array means that the parameter will either
#  accept one value, or an array of values. Single values do not need to be
#  sent "inside arrays".
#
#    [:string]
#    [:float]
#    [:time]
#    [User]
#    [Location]
#
#  In some cases the array may be ultimately parsed in the scope as a duration
#  or range of values (e.g. a range of dates, ranks, vote values, etc.). In this
#  case, two values is the maximum length of the array; more will be ignored.
#  But for arrays of model instances like [Name], any number of instances or
#  ids can be passed.
#
#  ### Hash
#
#  An attribute declared with a hash could mean several things, so syntax is
#  important.
#
#  If the first key in the hash is `:string` or `:boolean`, the parameter
#  value will be parsed as an `enum`. The declaration states allowable values,
#  and others are ignored.
#
#    { string: [:no, :either, :only] }
#    { boolean: [true] } # simply a way of saying "ignore false"
#
#  If the first key in the hash is `:subquery`, it's parsed as a subquery of
#  the specified model. That means any enclosed params will be sent to a new
#  Query instance of that model, and merged into the current query.
#  For more on this, see Query::Modules::Subqueries.
#
#    { subquery: :Observation }
#
#  If neither `:string`, `:boolean`, nor `:subquery` is the first key, the hash
#  is parsed as a hash of arguments to be sent to the scope of the same name.
#  Each argument is independently validated as declared.
#
#  For example, this is the declaration of the attribute `in_box`:
#
#  in_box: { north: :float, south: :float, east: :float, west: :float }
#
#  ############################################################################
#
#  == Class and Instance Methods
#  parameter_declarations::
#  takes_parameter?::
#  scope_parameters::
#  content_filter_parameters::
#  default_order::
#
#  == Instance Methods
#  relatable?::               Can a query of this model be converted to a
#                             subquery filtering results of another model?
#  subquery_of?(target)::
#  serialize::          Returns string which describes the Query completely.
#  record::
#
class Query::Base
  include ActiveModel::API
  include ActiveModel::Attributes
  include ActiveModel::Validations::Callbacks

  include Query::Modules::QueryRecords
  include Query::Modules::Subqueries
  include Query::Modules::Initialization
  include Query::Modules::Results
  include Query::Modules::Sequence
  include Query::Modules::Validation

  validates_with Query::Modules::Validator

  # "clean up" and reassign attributes before validation
  before_validation :clean_and_validate_params

  attr_writer :record

  def self.parameter_declarations
    { order_by: :string }
  end

  delegate :parameter_declarations, to: :class

  # Could use has_attribute? here, but it doesn't exist yet for ActiveModel.
  # Only called in ApplicationController::Queries#apply_one_content_filter
  def self.takes_parameter?(key)
    parameter_declarations.key?(key)
  end

  delegate :takes_parameter?, to: :class

  # :id_in_set must be moved to the last position so it can reorder results.
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

  # def self.subquery_parameters
  #   parameter_declarations.select { |key, _v| key.to_s.include?("_query") }
  # end

  # delegate :subquery_parameters, to: :class

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
  # was params.sort.to_h.merge(model: model.name).to_json
  def serialize
    attributes.compact.sort.to_h.merge(model: model.name).to_json
  end

  def record
    # This errors out if @record is not set since it
    # cannot find Query.get_record.  If you copy the
    # definition of get_record into the same scope
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
