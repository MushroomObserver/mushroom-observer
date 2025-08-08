# frozen_string_literal: true

#  == Query Superclass
#
#  This class encapsulates a hash of params that can produce an ActiveRecord
#  statement for a database query, that looks up one or more objects of a
#  given type, matching certain conditions in a certain order.
#
#  Queries are specified by a model.  The model specifies which kind
#  of objects are being requested, e.g. :Name or :Observation. They are
#  dyamically joined with any number of additional tables, as required by
#  sorting and selection conditions.
#
#  To filter query results, you can send additional parameters.  For example,
#  create_query(:Comment, for_user: user.id) retrieves comments posted on a
#  given user's observations.  Query saves the parameters alongside the model,
#  and together these fully specify a query that may be recreated and
#  executed at a later time, even potentially by another user (e.g., if users
#  share links that have query specs embedded in them). They can be serialized
#  and printed as a permalink, or carried along in the session while the user
#  is navigating around related records.
#
#  == Example Usage
#
#  Get observations created by @user:
#
#    query = Query.lookup(:Observation, by_users: [@user])
#
#  You may further tweak a query after it's been created:
#
#    query = Query.lookup(:Observation)
#    query.add_join(:names)
#    query.where << 'names.correct_spelling_id IS NULL'
#    query.order = 'names.sort_name ASC'
#
#  Now you may execute it in various ways:
#
#    num_results = query.num_results
#    ids         = query.result_ids
#    instances   = query.results
#
#
#
#  CREATING A NEW QUERY SUBCLASS
#
#  To make an ActiveRecord model queryable, create a new class that inherits
#  from this class, Query.
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
#    Query.create_query(
#      :Observation,
#      has_public_lat_lng: true,
#      region: "Massachusetts, USA",
#      names: { lookup: "Amanita" }
#    )
#
#  ## VALIDATION
#
#  For the sake of familiarity, Query classes use ActiveModel. Each instance of
#  a Query class is a data object with validatable attributes, instance methods
#  and class methods. The methods are mostly inherited from Query, and
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
#  Query::Validator to check for any validation errors that may have been
#  stored in the Query instance by `clean_and_validate_params`.
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
#    Query.create_query(:Name, pattern: "Lactarius",
#                              observation_query: { notes_has: "Symbiota" })
#
#  The validator calls
#
#    Query.create_query(:Observation, notes_has: "Symbiota")
#
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
#  ## DEFAULT ORDER
#
#  Each model should define a default search order (:default_order), which is a
#  keyword parsed by the `order_by` scope, and should map to a scope or class
#  method named `order_by_#{:default_order}` in `AbstractModel::Scopes`.
#
#  This order is also used by the prev and next actions when the specified query
#  no longer exists. For example, if you click on an observation from the main
#  index, prev and next travserse the results of an order_by: :rss_log query.
#  If the user comes back a day later, this query will have been culled by the
#  garbage collector (see Query::Modules::QueryRecords), so prev and next need
#  to be able to create a default query on the fly.
#
#  ## ALPHABETICAL BY
#
#  For indexes where we want users to be able to paginate the results by letter,
#  the Query class should specify which column to use for sorting. This should
#  be given as `Model[:column]`, in case it is being sorted on the column of a
#  joined table. Check existing examples.
#
#
#  ############################################################################
#
#  == Class methods
#
#  create_query::               Factory method for generating new queries.
#                               Takes a model name (symbol) and parameters.
#                               Instantiates a new Query and initializes some
#                               (but not all) accessor values.
#
#    NOTE: other class methods defined in modules
#
#  == Class and Instance Methods
#
#  scope_parameters::           Attributes that should be forwarded to scopes.
#                               Generally that's all of them, but we do have
#                               one, `preference_filter`, that's a flag
#                               indicating one or more user preference content
#                               filters have been automatically applied to the
#                               scope in ApplicationController.
#  content_filter_parameters::  Attributes that may be affected by user content
#                               filters. Queries may override these.
#  default_order::              Keyword that specifies an `order_by_#{keyword}`
#                               ordering scope, when there is no `order_by`
#                               parameter passed.
#  alphabetical_by::            `Model[:column]` that specifies what column to
#                               pull text values from, for indexes that offer
#                               pagination by letter. May be a joined column.
#
#  == Instance Methods
#
#  relatable?(target)::       Can the current class be called as a subquery of
#                             the target class, filtering its results?
#  subquery_of?(target)::     Is a query of this model serving as a subquery of
#                             the target in the current query?
#                             (Checks recursion.)
#  serialize::                Returns string which describes the Query
#                             completely.
#  record::                   The QueryRecord of the current query, if exists.
#
#  == Attributes of all Query instances:
#
#  model::              Class of model results belong to.
#  params::             Hash of parameters used to create query.
#  current::            Current location in query (for sequence operators).
#  subqueries::         Cache of subquery Query instances, used for filtering.
#
class Query
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

  # NOTE: Declare query subclass attributes with `query_attr`, a custom MO
  # method defined by monkey-patching `Class` in app/extensions/class.rb.
  # attribute `:order_by` is inherited by all subclasses, necessary for paging.
  query_attr(:order_by, :string)

  validates_with Query::Validator

  # "clean up" and reassign attributes before validation
  before_validation :clean_and_validate_params

  # This is the factory method for Query instances. It is most often called via
  # `Query.lookup` or others defined in `Query::Modules::QueryRecords`.
  # Always call `Query.create_query` (or `lookup`) to initialize a usable query
  # instance, rather than calling `Query::Subclass.new` directly.
  def self.create_query(model, params = {}, current = nil)
    klass = "Query::#{model.to_s.pluralize}".constantize
    # Initialize an instance, ignoring undeclared params:
    query = klass.new(params.slice(*klass.attribute_names))
    # Initialize `params`, where query stores the active `attributes`.
    query.params = query.attributes.compact
    # Initialize `subqueries`, to store any validated subquery instances.
    query.subqueries = {}
    query.current = current if current
    # Calling `valid?` reinitializes `params` after cleaning/validation.
    query.valid = query.valid?
    # query.initialize_query # if you want the attributes right away
    query
  end

  # `attribute_types` is a core Rails method, but it unexpectedly returns
  # string keys, and they are not accessible with symbols.
  def self.attribute_types
    super.symbolize_keys!
  end
  delegate :attribute_types, to: :class

  # Same with `attribute_names`
  def self.attribute_names
    super.map!(&:to_sym)
  end
  delegate :attribute_names, to: :class

  # Define has_attribute? here, it doesn't exist yet for ActiveModel.
  def self.has_attribute?(key) # rubocop:disable Naming/PredicatePrefix
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

  def self.type_tag
    name.demodulize.singularize.underscore.to_sym
  end
  delegate :type_tag, to: :class

  # Can the current class be called as a subquery of the target Query class?
  def relatable?(target)
    self.class.related?(target, model.name.to_sym)
  end

  # Is the current class being used as a subquery of the target class?
  # (Checks subquery recursion.)
  def subquery_of(target)
    self.class.current_or_related_query(target, model.name.to_sym, self)
  end

  # Defined in each subclass. Default order when `order_by` param not passed.
  def default_order
    self.class.default_order || :id
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

  def ==(other)
    serialize == other.try(&:serialize)
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
