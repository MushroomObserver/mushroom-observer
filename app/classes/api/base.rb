# encoding: utf-8

class API
  API_VERSION = 1.0

  def self.version
    API_VERSION
  end

  attr_accessor :params
  attr_accessor :method
  attr_accessor :action
  attr_accessor :version
  attr_accessor :user
  attr_accessor :errors

  # Give other modules ability to do additional initialization.
  class_inheritable_accessor :initializers
  self.initializers = []

  # Initialize and process a request.
  def self.execute(params)
    api = instantiate_subclass(params)
    api.handle_version
    api.authenticate_user
    api.process_request
    return api
  rescue API::Error => e
    api ||= self.new(params)
    api.errors << e
    e.fatal = true
    return api
  end

  def self.instantiate_subclass(params)
    action = params[:action].to_s
    subclass = "API::#{action.camelize}API"
    subclass = subclass.constantize
    subclass.new(params)
  rescue
    raise BadAction.new(action)
  end

  # :stopdoc:
  def initialize(params={})
    self.params = params
    self.errors = []
    initializers.each {|x| instance_exec(&x)}
  end

  def handle_version
    version = parse_float(:version)
    if version.blank?
      version = self.class.version
    elsif !version.match(/^\d+\.\d+$/)
      raise BadVersion.new(version)
    else
      self.version = version.to_f
    end 
  end

  def authenticate_user
    key_str = parse_string(:api_key)
    if !key_str
      ::User.current = self.user = nil
    elsif key = ApiKey.find_by_key(key_str)
      ::User.current = self.user = key.user
      key.touch!
    else
      raise BadApiKey.new(key_str)
    end
  end

  def process_request
    self.method = parse_string(:method)
    if !method
      raise MissingMethod.new
    elsif respond_to?(method)
      send(method)
    else
      raise BadMethod.new(method)
    end
  end

  def abort_if_any_errors!
    raise AbortDueToErrors.new() if errors.any?
  end

  def must_authenticate!
    raise MustAuthenticate.new() unless user
  end
end
