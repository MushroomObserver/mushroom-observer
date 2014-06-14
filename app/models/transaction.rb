# encoding: utf-8
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
#  updated_at::         Date/time it was logged.
#  query::              Stringified query.
#
#  == Class Methods
#
#  all_methods::        List of allowable methods.
#  all_actions::        List of allowable actions.
#  <method>_<action>::  Create a GET/PUT/POST/DELETE request.
#  create::             Create an arbitrary request.
#
#  == Instance Methods
#
#  text_name::          Returns simple summary for debugging.
#  method::             Return request method, e.g., "GET".
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
#    xacts = Transaction.all(:conditions => ['`updated_at` > "?"', 1.day.ago])
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
    [ 'get', 'put', 'post', 'delete' ]
  end

  # Set of allowed actions.
  def self.all_actions
    [
      'comment',
      'image',
      'interest',
      'license',
      'location',
      'location_description',
      'name',
      'name_description',
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

  # Create new transaction.
  #
  #   xact = Transaction.new(args)
  #   xact.create_query
  #   xact.execute
  #   xact.save
  #
  def initialize(args=nil)
    if self.args = args
      args[:_user] ||= User.current if User.current
      args[:_time] ||= Time.now
    end
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
    return # DISABLE TEMPORARILY
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
    return # DISABLE TEMPORARILY
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

  # Execute the given transaction.  Parses the query string if necessary.
  #
  #   # Rerun last transaction logged.
  #   Transaction.last.execute
  #
  #   # Build new transaction and execute it immediately.
  #   Transaction.get_user(:login => 'fred').execute
  #
  def execute
    parse_query if !args
    API.execute(args)
  end

  ##############################################################################
  #
  #  :section: Parsing and Encoding
  #
  ##############################################################################

  # Extract from String.
  def parse_query
    self.args = deconstruct_query(query)
  end

  # Mash into String.
  def create_query
    # Just make absolutely sure we don't accidentally save authentication.
    args.delete(:auth_id)   if args.has_key?(:auth_id)
    args.delete(:auth_code) if args.has_key?(:auth_code)

    # This validates ids and converts ActiveRecords to sync_ids.
    validate_args(args)

    # This turns the request into a String.
    self.query = construct_query(args)
  end

  # Validate arguments and convert all ActiveRecord instances into sync_ids.
  def validate_args(args)
    args.each do |key, val|

      # Key need only respond to 'to_s', but I'm more strict.
      if (!key.is_a?(Symbol) and !key.is_a?(String)) or
         key.to_s.match(/\W/)
        raise "Invalid argument #{key.class}: #{key}"
      end

      # Convert ActiveRecords into sync_id.
      if val.is_a?(ActiveRecord::Base)
        if val.respond_to?(:sync_id) && (val2 = val.sync_id)
          args[key] = val2
        else
          raise "Missing sync_id for :#{key} = #{val.class} ##{val.id || 'nil'}"
        end

      # Convert Array of ActiveRecords into comma-separated list of sync_ids.
      elsif val.is_a?(Array) and val.all? {|v| v.is_a?(ActiveRecord::Base)}
        args[key] = val.map do |val2|
          if val2.respond_to?(:sync_id) && (val3 = val2.sync_id)
            val3
          else
            raise "Missing sync_id for :#{key} = #{val2.class} ##{val2.id || 'nil'}"
          end
        end.join(',') 

      # Let ActiveSupport::TimeWithZone take care of timezones.
      elsif val.is_a?(Time)
        args[key] = val.in_time_zone

      # Allow only these types of values.
      elsif !val.is_a?(NilClass)   &&
            !val.is_a?(TrueClass)  &&
            !val.is_a?(FalseClass) &&
            !val.is_a?(String) &&
            !val.is_a?(Symbol) &&
            !val.is_a?(Fixnum) &&
            !val.is_a?(Float)  &&
            !val.is_a?(Date)   &&
            !val.is_a?(Time)
        raise "Invalid value for :#{key} = #{val.class}: #{val}"
      end
    end
  end

  # Convert request into a String.  (Inverse of +deconstruct_query+.)
  # (NOTE: I originally used XML-RPC, but that is hideously inefficient.)
  def construct_query(args)
    args.map do |key, val|
      key.to_s + ' ' + case val
      when NilClass   ; 'nil'
      when TrueClass  ; 'true'
      when FalseClass ; 'false'
      when String     ; '"' + val.gsub(/[\\\r\n]/) {|x| x == '\\' ? '\\\\' : x == "\n" ? '\\n' : ''}
      when Symbol     ; ':' + val.to_s
      when Fixnum     ; val.to_s
      when Float      ; val.to_s
      when Date       ; val.to_s
      when Time       ; val.utc.strftime('%Y-%m-%d %H:%M:%S')
      else
        raise "Invalid type in construct_query: #{val.inspect}"
      end
    end.join("\n")
  end

  # Parse request from String.  (Inverse of +construct_query+.)
  def deconstruct_query(query)
    args = {}
    query.split("\n").each do |line|
      line.match(' ')
      args[$`.to_sym] = case (val = $')
      when 'nil'      ; nil
      when 'true'     ; true
      when 'false'    ; false
      when /^"/       ; $'.gsub(/\\\\|\\n/) {|x| x == '\\n' ? "\n" : '\\'}
      when /^:/       ; $'.to_sym
      when /^-?\d+$/  ; val.to_i
      when /^-?\d+\./ ; val.to_f
      when /^\d\d\d\d-\d\d-\d\d$/
                        Date.parse(val)
      when /^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/
                        Time.utc($1, $2, $3, $4, $5, $6)
      else
        raise "Invalid value in deconstruct_query: #{val.inspect}"
      end
    end
    return args
  end
end
