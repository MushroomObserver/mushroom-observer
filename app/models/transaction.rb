#
#  = Transaction Model
#
#  A Transaction is a single, generally atomic, operation on the database.  Any
#  API request -- GET, POST, etc. -- can be logged, stored, retrieved, and
#  later executed via a Transaction record.  In practice, only write-requests
#  are logged, primarily for the purpose of keeping remote servers in sync.
#
#  == Attributes
#
#  modified::           Date/time it was logged.
#  query::              XML-RPC query.
#
#  == Class Methods
#
#  all_methods::        List of allowable methods.
#  all_actions::        List of allowable actions.
#  <method>_<action>::  Create a GET/PUT/POST/DELETE request.
#  create::             Create an arbitrary request.
#  xmlrpc_reader::      Get default XML-RPC parser.
#  xmlrpc_writer::      Get default XML-RPC writer.
#
#  == Instance Methods
#
#  text_name::          Returns simple summary for debugging.
#  method::             Return request method, e.g., :get.
#  action::             Return action, e.g., 'observations'.
#  args::               Return hash of arguments.
#  execute::            Execute query, return API instance.
#
#  ==== Protected methods
#  parse_query::        Parse args from query string.
#  create_query::       Create query string from args.
#  convert_ids::        Convert all values which are Model's into +sync_id+.
#
#  == Callbacks
#
#  None.
#
#  == Examples
#
#    # Delete a given user and log it in transactions log.
#    Transaction.delete_user(:id => user_id).execute
#
#    # Build XML feed of all the transactions in the last day.
#    xacts = Transaction.all(:conditions => ['`modified` > "?"', 1.day.ago])
#    xml.transactions(:number => xacts.length) do
#      xacts.each do |xact|
#        if filter_actions.include?(xact.action)
#          xml.transaction xact.query
#        end
#      end
#    end
#
################################################################################

class Transaction < AbstractModel
  require 'xmlrpc/client'

  # Cache query's args.
  attr_accessor :args

  # Returns method and action for debugging.
  def text_name
    "#{method} #{action}"
  end

  # Grab method out of args.
  def method
    parse_query if !@args
    @args[:method]
  end

  # Grab action out of args.
  def action
    parse_query if !@args
    @args[:action]
  end

  # Set of allowed methods.
  def self.all_methods
    [
      'get', 'put', 'post', 'delete',
      'login', 'logout', 'view',
    ]
  end

  # Set of allowed actions.
  def self.all_actions
    [
      'comment',
      'image',
      'interest',
      'license',
      'location',
      'name',
      'naming',
      'notification',
      'observation',
      'project',
      'species_list',
      'synonym',
      'user_group',
      'user',
      'vote',
    ]
  end

  # Get default XML-RPC parser.
  #
  #   method, args = Transaction.xmlrpc_reader.parse(query)
  #
  def self.xmlrpc_reader
    @@xmlrpc_reader ||= XMLRPC::XMLParser::REXMLStreamParser.new
    # @@xmlrpc_reader ||= XMLRPC::Config.DEFAULT_PARSER.new
  end

  # Get default XML-RPC parser.
  #
  #   query_str = Transaction.xmlrpc_writer.methodCall(method, args)
  #
  def self.xmlrpc_writer
    @@xmlrpc_writer ||= XMLRPC::Create.new
  end

  # Create new transaction.
  #
  #   xact = Transaction.new(args)
  #   xact.create_query
  #   xact.execute
  #   xact.save
  #
  def initialize(args={})
    self.args = args
    args[:_user] ||= User.current if User.current
    args[:_time] ||= Time.now
    super()
  end

  # Instantiate, create query string, save, return instance.
  #
  #   Transaction.create(args).execute
  #
  # *NOTE*: This calls create_query, and it implicitly makes a few
  # modifications to the arguments.
  # 1. Adds +_time+ and +_user+.
  # 2. Removes +auth_id+ and +auth_code+ (not necessary via Transaction).
  # 3. Converts any values that are Model instances into +sync_id+.
  #
  # *NOTE*: It is okay to include +id+ in POST requests -- API will use this
  # when setting the sync_id of the new record.  If +id+ is not present, it
  # assumes it is being created for the first time now, and uses the new
  # record's id as the basis for the sync_id.  If +id+ _is_ present, it assumes
  # it was already created remotely, and uses _that_ as the sync_id for the new
  # record.
  def self.create(args)
    xact = new(args)
    xact.create_query
    xact.save
    return xact
  end

  # Convenience wrappers of the form "method_action".  Instantiates, saves and
  # returns a Transaction object.
  #
  #   Transaction.delete_image(:id => 1234).execute
  #
  def self.method_missing(*args)
    if args[0].to_s.match(/^([a-z]+)_(\w+)$/) &&
       all_methods.include?(method=$1) &&
       all_actions.include?(action=$2)
      if args.length < 1 || args.length > 2
        raise "Incorrect number of arguments to Transaction##{method}_#{action}, expect one or two."
      end
      args2 = (args[1] || {}).dup
      args2[:method] = method
      args2[:action] = action
      create(args2)
    else
      super(*args)
    end
  end

  # Execute the given transaction.  Parses the XML-RPC query string if necessary.
  #
  #   # Rerun last transaction logged.
  #   Transaction.last.execute
  #
  #   # Build new transaction and execute it immediately.
  #   Transaction.get_user(:login => 'fred').execute
  #
  def execute
    API.execute(args)
  end

################################################################################

# These should be protected but you can't call protected instance methods from
# a class method even if it's the same class(!)
# protected

  # Extract method, action, args from XML-RPC query string.
  def parse_query
    method, args = self.class.xmlrpc_reader.parseMethodCall(query)
    args = args[0]
    if !args.is_a?(Hash)
      raise "Invalid transaction query; expect a single hash of arguments."
    end
    args = Args.new(args)
    args[:method] = method
# print "PARSE QUERY: [#{args.inspect}]\n"
    self.args = args
  end

  # Trivial subclass of Hash that forces all keys to String.  This helps
  # avoid the whole obnoxious "is it a Symbol or String" fiasco, just like
  # the CGI params object does.  It returns keys as Symbols, but internally
  # everything is done as String.
  class Args
    def initialize(x); @hash = x; end
    def [](k); @hash[k.to_s]; end
    def []=(k,v); @hash[k.to_s] = v; end
    def keys; @hash.keys.map(&:to_sym); end
    def has_key?(k); @hash.has_key?(k.to_s); end
    alias key? has_key?
    alias include? has_key?
    def delete(k); @hash.delete(k.to_s); end
    def inspect; @hash.inspect; end
  end

  # Create XML-RPC string from method, action, args.
  def create_query

    # XML-RPC requires method be listed separately; we mash it in with
    # everything else.
    args = self.args.dup
    method = args[:method]
    args.delete(:method)

    # Just make absolutely sure we don't accidentally save authentication.
    args.delete(:auth_id)   if args.has_key?(:auth_id)
    args.delete(:auth_code) if args.has_key?(:auth_code)

    # This validates ids and converts ActiveRecords to sync_ids.
    convert_ids(args)

    # Create the actual XML-RPC query.
# print "CREATE QUERY: [#{method.inspect}, #{args.inspect}]\n"
    self.query = Transaction.xmlrpc_writer.methodCall(method, args)
  end

################################################################################

private

  # Convert all ActiveRecord instances in args to sync_ids.
  def convert_ids(args)
    args.each do |key, val|

      # Key need only respond to 'to_s', but I'm more strict.
      if !key.is_a?(Symbol) &&
         !key.is_a?(String)
        raise "Invalid argument #{key.class}: #{key}"
      end

      # Convert ActiveRecords into sync_id.
      if val.is_a?(ActiveRecord::Base)
        if val.respond_to?(:sync_id) && (val2 = val.sync_id)
          args[key] = val2
        else
          raise "Missing sync_id for :#{key} = #{val.class} ##{val.id || 'nil'}"
        end

      # Let ActiveSupport::TimeWithZone take care of timezones, etc.
      elsif val.is_a?(Time)
        args[key] = val.in_time_zone

      # Allow only these types of values.  We could in theory allow nils,
      # Bignums, Arrays, Hashes and Structs, but we have no need of these.
      # Nils, in particular, are problematic in my opinion, since there is no
      # way to distinguish nil from "" when values are passed as strings.
      elsif !val.is_a?(TrueClass)  &&
            !val.is_a?(FalseClass) &&
            !val.is_a?(Fixnum) &&
            !val.is_a?(Float)  &&
            !val.is_a?(String) &&
            !val.is_a?(Symbol) &&
            !val.is_a?(Date)
        raise "Invalid value for :#{key} = #{val.class}: #{val}"
      end
    end
  end
end
