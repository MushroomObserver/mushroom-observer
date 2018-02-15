#
#  = Wrapper Class
#
#  Handy (if silly) class used to wrap a structure so that its members are
#  available as methods.  Useful to make structs masquerade as objects for
#  testing purposes.
#
#  *NOTE*:: BlankSlate is in the "builder" vendor package in ActiveSupport --
#  it defines a superclass with (almost) *no* methods at all.
#
#  == Example
#
#    # Construct:
#    obj = Wrapper.new(
#      :attr1 => val1,
#      :attr2 => val2,
#      ...
#    )
#
#    # Alternate construction:
#    obj = Wrapper.new
#    obj.attr1 = val1
#    obj.attr2 = val2
#    ...
#
#    # Result:
#    obj.attr1  -->  val1
#    obj.attr2  -->  val2
#    ...
#
################################################################################

class Wrapper < BlankSlate
  # Contructor takes a Hash of attributes you want the object to have.
  def initialize(attributes = {})
    @attributes = attributes
  end

  # Display object's attributes.
  def inspect
    @attributes.inspect.sub(/^\{/, "<Wrapper: ").sub(/\}$/, ">")
  end

  def send(*args) # :nodoc:
    method_missing(*args)
  end

  def method_missing(name, *args) # :nodoc:
    if name.to_s.match(/^(\w+)=$/)
      @attributes[Regexp.last_match(1).to_sym] = args[0]
    else
      @attributes[name.to_s.to_sym]
    end
  end

  def respond_to?(name) # :nodoc:
    name.to_s.match(/=$/) ||
      @attributes.key?(name.to_s.to_sym)
  end
end
