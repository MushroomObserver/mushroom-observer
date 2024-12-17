# frozen_string_literal: true

class Query::SpeciesListAll < Query::SpeciesListBase
  def initialize_flavor
    add_sort_order_to_title
    super
  end

  # Only instance methods have access to params.
  def default_order
    if params[:user_where].present? || params[:location].present?
      "name"
    else
      "title"
    end
  end
end
