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
#  or `result_ids` methods, each non-nil attribute of the Query instance gets
#  sent to an ActiveRecord scope of the corresponding model; scopes are chained
#  to return the results. Query parameters must therefore each correspond to a
#  scope of the AR model.
#
#  Each Query class declares the parameters it will accept, and what type of
#  data each parameter expects, in the attributes at the top of the class.
#  You initialize a new Query instance with any combination of these.
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
#  and class methods. The methods are mostly inherited from Query::Base, and
#  defined either here, or in one of the included Query::Modules.
#
#  The main difference from ActiveRecord objects (that also use ActiveModel) is
#  attribute validation. ActiveRecord attributes must have data types that can
#  be validated and stored in a database. _ActiveModel_ attributes are "ad hoc"
#  and temporary. Because they don't need to be stored in a database, they can
#  have any data type. They only need to "work" for the use case — a form, a
#  query, etc. But we can define the same `validate` methods as on AR models.
#
#  In our case, we define our own validator and data type. That data type is
#  `query_param`, and the attribute values are checked and sanitized by
#  Query::Modules::Validation on initialization. Calling `valid?` uses
#  Query::Modules::Validator to check for any validation errors that may
#  have been stored in the Query instance by `clean_and_validate_params`.
#
#  `valid?` should mean the parameter values are usable by the corresponding
#  ActiveRecord scope in each model. The scopes are what actually execute the
#  database query and define the parameter requirements.
#
#  ## PARAMETER DECLARATIONS
#
#  Query parameter names must map to AR scope names 1:1 (with few exceptions).
#  So the first task in making a class queryable is to write scopes for the
#  each attribute of the model that you want to be able to query.
#
#  For example, in the query above, the parameter `has_public_lat_lng` is also a
#  scope of our Observation model that accepts a Boolean value. It is defined
#  to find observations that have a `lat` value and where `gps_hidden` is false.
#  `region` is an Observation scope that accepts a string, and finds
#  observations within a given region. The scope `names` finds observations in
#  given taxa. `names` accepts a hash of arguments, `lookup` being required.
#  But all of these requirements and logic are ultimately defined in the scope;
#  Query is simply there to gather and store them, and pass them along.
#
#  Since the scopes can only accept certain types of data, Query needs to
#  validate (and sometimes "clean") the attributes passed to the Query instance.
#  Even though `query_param` is a single declared data type, it has a custom
#  attribute option `:accepts` that you use to pass an argument describing how
#  the attribute should be validated. (We don't differentiate between
#  `query_param` types at the attribute level because they are all validated
#  recursively, and nested values may use the same methods as top-level values.)
#
#  To keep attribute assignment from getting too verbose, we assign them using a
#  custom method `query_attr`, whose second argument is the value of `:accepts`.
#  See app/extensions/class.rb for the definition of `query_attr`. This argument
#  expects a special syntax declaring a validation type for each attribute, and
#  telling Query::Modules::Validation how to parse the attribute value.
#
#  It uses the following patterns:
#
#  ### Simple values
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
#  doesn't do any parsing of the string. It simply forwards the string to the
#  scope of the same name. The parsing is all done by the scope.
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
#  In some cases the scope may be configured to parse the array as a range of
#  values (e.g. of dates, ranks, etc.). In these scopes, passing one value
#  is valid and often considered as a minimum value. If the second value matches
#  the first, some scopes parse this as "match this value only". In all scopes
#  expecting range arrays, any values after the second are ignored.
#
#  For scopes accepting arrays of model instances like [Project], you can pass
#  any number of objects or ids, up to a limit defined in `MO.query_max_array`.
#
#  ### Hash
#
#  An attribute declared with a hash could mean several things, so syntax is
#  important.
#
#  If the first key in the hash is `:string` or `:boolean`, the parameter
#  value will be parsed like an ActiveRecord "enum". The declaration should
#  state an array of allowable values; others will be ignored.
#
#    { string: [:no, :either, :only] }
#    { boolean: [true] } # this is a way of saying "ignore false"
#
#  If the first key in the hash is `:subquery`, the attribute is parsed as a
#  subquery of the specified model.
#
#    { subquery: :Observation }
#
#  Subqueries validate enclosed params by instantiating a new Query of the
#  subquery model, sending the enclosed hash of params. For example:
#
#    Query.new(:Name, pattern: "Lactarius",
#                     observation_query: { notes_has: "Symbiota" })
#
#  The validator will call `Query.new(:Observation, notes_has: "Symbiota")`,
#  to make sure that the params are valid and the subquery will work. However,
#  during execution of the above query, the `notes_has` subparam is simply sent
#  to the Name model's scope `:observation_query`. That uses the params to call
#  scopes of the subquery (Observation) model, and merges the subquery into
#  the current Name query. For more on this, see Query::Modules::Subqueries.
#
#  If neither `:string`, `:boolean`, nor `:subquery` is the first key, the hash
#  is parsed as a hash of arguments to be sent to the scope of the same name.
#  Each argument is independently validated as declared. For example, this is
#  the declaration of the attribute `in_box`:
#
#    { north: :float, south: :float, east: :float, west: :float }
#
#  Each sub-param is validated as a :float.
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

  attr_writer :record

  # Declare query attributes with method defined in app/extensions/class.rb
  query_attr(:order_by, :string)

  validates_with Query::Modules::Validator

  # "clean up" and reassign attributes before validation
  before_validation :clean_and_validate_params

  # `attribute_types` is a core Rails method, but it unexpectedly returns
  # string keys, and they are not accessible with symbols.
  def self.attribute_types
    super.symbolize_keys!
  end

  delegate :attribute_types, to: :class

  # Define has_attribute? here, it doesn't exist yet for ActiveModel.
  def self.has_attribute?(key) # rubocop:disable Naming/PredicateName
    attribute_types.key?(key)
  end

  delegate :has_attribute?, to: :class

  # :id_in_set must be moved to the last position so it can reorder results.
  def self.scope_parameters
    excepts = [:id_in_set, :preference_filter]
    @scope_parameters = attribute_types.except(*excepts).keys + [:id_in_set]
  end

  delegate :scope_parameters, to: :class

  # returns keys
  def self.content_filter_parameters
    filters = Query::Filter.all
    @content_filter_parameters ||= filters.each_with_object(Set[]) do |f, set|
      set << f.sym
    end.freeze
  end

  delegate :content_filter_parameters, to: :class

  # def self.subquery_parameters
  #   attribute_types.select { |key, _v| key.to_s.include?("_query") }
  # end

  # delegate :subquery_parameters, to: :class

  def self.model
    name.demodulize.singularize.constantize
  end

  delegate :model, to: :class

  # Can the current class be called as a subquery of the target Query class?
  def relatable?(target)
    self.class.related?(target, model.name.to_sym)
  end

  def subquery_of(target)
    self.class.current_or_related_query(target, model.name.to_sym, self)
  end

  def default_order
    self.class.default_order || :id
  end

  def ==(other)
    serialize == other.try(&:serialize)
  end

  # Serialize the query params, adding the model, for saving to a QueryRecord.
  # We use this column of QueryRecord to identify an existing query record that
  # matches current params, and sometimes to recompose a query from the string.
  # That's why the keys are sorted here before being serialized via `to_json` -
  # when matching, strings must match exactly.
  #
  # NOTE: QueryRecord[:description] is not a Rails-serialized column; we call
  # `to_json` here to serializate it ourselves. Using SQL to compare serialized
  # strings is more efficient than making it a Rails-serialized column and using
  # Ruby to compare hashes (in whatever order), because in a serialized column
  # you can't use SQL on the column value, you have to compare parsed instances.
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
