# frozen_string_literal: true

class Lookup::Users < Lookup
  MODEL = User
  TITLE_COLUMN = :login

  def initialize(vals, params = {})
    super
  end

  def lookup_method(name)
    User.where(login: User.remove_bracketed_name(name))
  end
end
