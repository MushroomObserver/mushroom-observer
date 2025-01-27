# frozen_string_literal: true

class Lookup::Users < Lookup
  def initialize(vals, params = {})
    @model = User
    @name_column = :login
    super
  end

  def lookup_method(name)
    User.where(login: User.remove_bracketed_name(name))
  end
end
