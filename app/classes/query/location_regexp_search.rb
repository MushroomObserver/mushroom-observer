# frozen_string_literal: true

class Query::LocationRegexpSearch < Query::LocationBase
  def parameter_declarations
    super.merge(
      regexp: :string
    )
  end

  def initialize_flavor
    regexp = escape(params[:regexp].to_s.strip_squeeze)
    where << "locations.name REGEXP #{regexp}"
    super
  end
end
