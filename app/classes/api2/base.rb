# frozen_string_literal: true

#
#  = API2
#
#  == Overview of class structure and interaction.
#
#  Each API request is encapsulated by a sinle instance of a subclass of API2.
#  Most requests are tied one-to-one to an ActiveRecord model.  Thus most
#  subclasses are derived from API2::ModelAPI < API2.
#
#  The API2 instance is given the hash of (string) parameters verbatim from
#  an HTTP request.  (Although note that the request could in principle come
#  from any source, just so long as it takes the form of a set of string
#  key-value pairs, in UTF-8 encoding.)  Callers instantiate the request via
#  the API2 class method +execute+.  This takes care of selecting the
#  appropriate subclass for you, as well as handling errors, authentication
#  and actually processing the request.  It's one-stop shopping. Example
#
#    api = API2.execute(method: post, action: comment, target: etc...)
#
#  The returned instance knows all the details about the request, whether it
#  succeeded, which Query was used (if any), what the results were, etc.
#
#  == Public instance methods
#
#    method           Method: :get, :post, :patch, :delete
#    action           "Action": :comment, :name, :observation, etc.
#    user             User whose ApiKey was passed in for authentication.
#    api_key          ApiKey passed in for authentication.
#
#    params           Validated hash of parameters you passed in.
#    expected_params  Hash of parameters API tried to parse.  This is a full
#                     set of available parameters for that method / action.
#                     Values are API2::ParameterDeclaration instances.
#
#    errors           Array of errors which occur while updating or destroying
#                     records.  (See section on exception handling below.)
#
#    query            Query instance used by GET, PATCH and DELETE to select
#                     instances for retrieval, update and destruction, resp.
#
#    results          Array of results (ActiveRecord subclass instances).
#    result_ids       Array of result ids.
#    num_results      Number of results total.
#    page_length      Number of results per page.
#    num_pages        Number of pages.
#    page_number      Number of page requested for paginated results.
#    detail           Requested detail level: :none, :low, :high.
#
#  == Internal model-related stubs and callbacks
#
#  The main four entry points (called by API2.execute) are:
#
#    get              Parse and execute GET request.
#    post             Parse and execute POST request.
#    patch            Parse and execute PATCH request.
#    delete           Parse and execute DELETE request.
#
#  These are the "stubs" subclasses will typically provide: (Subclasses may
#  override any of the above, of course, too.  Especially useful for disabling
#  an entire request method for a given model, for example.)
#
#    query_params     Returns hash of parameters to give to Query.
#    create_params    Returns hash of parameters to give to Model.create.
#    update_params    Returns hash of parameters to give to record.update.
#
#  These are some useful callbacks to fine-tune things:
#
#    query_flavor     Allows you to choose a Query flavor other than "all".
#
#    validate_create_params!(params) Called in POST after query_params.
#    validate_update_params!(params) Called in PATCH after update_params.
#
#    before_create(params) Called in POST after validation, before creating.
#    after_create(obj)     Called in POST immediately after creating record.
#
#    build_setter     Returns "lambda" called on each object for PATCH.
#    build_deleter    Returns "lambda" called on each object for DELETE.
#
#  Check out, for example, CommentAPI for a simple example.  Check out
#  ObservationAPI or ProjectAPI for more involved examples.  You should
#  generally let ModelAPI do most of the work and expend most of your effort
#  in parsing/validating query_params, create_params and update_params.  This
#  will do the vast majority of the work for you nicely.
#
#  But if associated records are being affected, then you will need to pull off
#  the corresponding parameters and store them locally (typically as instance
#  variables for simplicity).  Do not return them from create_params or
#  update_params!  Then perform the necessary construction, modifications and
#  clean-up (for POST, PATCH and DELETE requests, respectively) in one or more
#  callbacks.
#
#  An important technique for making nontrivial modifications to PATCH and
#  DELETE requests is by overriding the lambdas.  The "factory defaults" have
#  been kept very minimal in order to make it easy to override them.  They just
#  check permission and call update! and destroy, respectively.
#
#    def build_setter(params)
#      lambda do |obj|
#        must_have_edit_permission!(obj)
#        obj.update!(params)
#        obj
#      end
#    end
#
#    def build_deleter
#      lambda do |obj|
#        must_have_edit_permission!(obj)
#        obj.destroy!
#      end
#    end
#
#  == Parsing and validation of parameters
#
#  All parameters should be parsed using the provided parser classes.  These
#  classes not only standardize syntax and validation, but they also keep track
#  of which parameters are allowed for a given type of request, along with each
#  parameters "declaration" (that is, the expected syntax and limits).  The
#  result is that the client can autodiscover all the available parameters (via
#  the special "help" pseudoparameter).  Errors are raised as exceptions which
#  must be caught by the client (or Api2Controller).
#
#  There are four standard parsing methods:
#
#    parse(type, name, args)         Takes a single value.
#    parse_array(type, name, args)   Takes a comma-separated list.
#    parse_range(type, name, args)   Takes a pair of values separated by a dash.
#    parse_ranges(type, name, args)  Takes a list of dashed pairs.
#
#  Here +type+ is the data type (e.g., :boolean, :float, :enum, :object, etc.),
#  +name+ is the parameter name (also a Symbol like :id), and args is an
#  optional Hash of options (e.g., limit: 1..256).  The type leads to the
#  particular API2::Parser subclass, e.g., :string goes to API2::Parser::String.
#
#  Creating new parser subclasses is extremely easy.  Most of the work is
#  done for you in API2::Parsers::Base.  All you need to do is provide a +parse+
#  method.  For example, an integer parser might be just this:
#
#    def parse(str)
#      raise BadParameterValue.new(str, :integer) unless str =~ /^-?\d+$/
#      return str.to_i
#    end
#
#  If you want to add the ability to define an accepted range via an optional
#  :limit argument (which takes a Range), you might extend it like this:
#
#    def parse(str)
#      raise BadParameterValue.new(str, :integer) unless str =~ /^-?\d+$/
#      val = str.to_i
#      if (limit = args[:limit])
#        raise BadLimitedParameterValue.new(str, limit) \
#          unless limit.include?(val)
#      end
#      return val
#    end]
#
#  A frequent modification is to cause trivial ranges -- that is, ranges
#  where upper and lower end are the same -- to collapse into a single scalar.
#  Just add a wrapper on +parse_range+ like this:
#
#    def parse_range
#      val = super || return
#      val.begin == val.end ? val.begin : val
#    end
#
#  This will cause "1-2,4,6" to parse to [ 1..2, 4, 6 ] as expected (using
#  parse_ranges method).
#
#  Deriving subclasses from other parsers is also a very effective way to
#  build new parsers.  A common example is parsing enumerated parameters:
#
#    class SizeParser < EnumParser
#      def initialize(api, key, args)
#        args[:limit] = Image.all_sizes
#        super
#      end
#    end
#
#  == Exception handling
#
#  Fatal errors are raised as exceptions.  This includes all errors which occur
#  anywhere during GET or POST requests, but only those errors which occur
#  prior to looping through selected records in PATCH and DELETE requests.
#  Once it starts updating or deleting records, it will attempt to update or
#  delete every single record.  And errors or exceptions encountered during
#  this process are added to the +errors+ Array.
#
#  Most exceptions originating from within API code (as opposed to Query or
#  ActiveRecord or elsewhere in the Rails app) are subclasses of API2::Error
#  class.  Access the full error message via +to_s+ or +t+ methods (for
#  unformatted and formatted, respectively).  The language "tag" is
#  automatically generated from the class name (lowercased and underscored with
#  "::" turned into an underscore), and passed in +args+.  Example:
#
#    api_file_missing: File "[file]" is missing.
#
#  The corresponding FileMissing exception class is just this:
#
#    class FileMissing < Error
#      def initialize(file)
#        super()
#        args.merge(file: file.to_s)
#      end
#    end
#
#  The widely-used BadParameterValue exception further refines the message
#  by adding the parameter type to the language tag:
#
#    api_bad_xxx_parameter_value
#
#  Don't worry about forgetting to add these.  The unit test
#  +localization_files_test.rb+ will automatically search through all the
#  parsers looking for missing error message.
#
class API2
  API_VERSION = 2.0

  def self.version
    API_VERSION
  end

  attr_accessor :params
  attr_accessor :method
  attr_accessor :action
  attr_accessor :version
  attr_accessor :user
  attr_accessor :api_key
  attr_accessor :errors

  # Give other modules ability to do additional initialization.
  class_attribute :initializers
  self.initializers = []

  # Initialize and process a request.
  def self.execute(params)
    api = instantiate_subclass(params)
    api.handle_version
    api.authenticate_user
    api.process_request
    api
  rescue API2::Error => e
    api ||= new(params)
    api.errors << e
    e.fatal = true
    api
  end

  # :stopdoc:
  def self.instantiate_subclass(params)
    action = params[:action].to_s
    subclass = "API2::#{action.camelize}API"
    subclass = subclass.constantize
    subclass.new(params)
  rescue StandardError
    raise(BadAction.new(action))
  end

  def initialize(params = {})
    self.params = params
    self.action = params[:action]
    self.errors = []
    initializers.each { |x| instance_exec(&x) }
  end

  def handle_version
    self.version = parse(:float, :version)
    if version.blank?
      self.version = self.class.version
    elsif !version.match(/^\d+\.\d+$/)
      raise(BadVersion.new(version))
    else
      self.version = version.to_f
    end
  end

  def authenticate_user
    key_str = parse(:string, :api_key)
    if !key_str
      User.current = self.user = nil
      User.current_location_format = :postal
    else
      key = ApiKey.find_by(key: key_str)
      raise(BadApiKey.new(key_str))        unless key
      raise(ApiKeyNotVerified.new(key))    unless key.verified
      raise(UserNotVerified.new(key.user)) unless key.user.verified

      User.current = self.user = key.user
      User.current_location_format = :postal
      # (that overrides user pref in order to make it more consistent for apps)
      key.touch!
      self.api_key = key
    end
  end

  def process_request
    tmp_method  = parse(:string, :method)
    self.method = tmp_method.downcase.to_sym
    raise(MissingMethod.new)     unless method
    raise(BadMethod.new(method)) unless respond_to?(method)

    send(method)
  end

  def abort_if_any_errors!
    raise(AbortDueToErrors.new) if errors.any?
  end

  def must_authenticate!
    raise(MustAuthenticate.new) unless user
  end
end
