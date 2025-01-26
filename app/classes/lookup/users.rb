# frozen_string_literal: true

class Lookup::Users < Lookup
  def initialize(vals, params = {})
    super
    @model = User
  end

  def lookup_method(name)
    User.where(login: User.remove_bracketed_name(name))
  end
end
