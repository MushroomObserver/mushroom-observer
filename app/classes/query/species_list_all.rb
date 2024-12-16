# frozen_string_literal: true

class Query::SpeciesListAll < Query::SpeciesListBase
  def initialize_flavor
    add_sort_order_to_title
    super
  end

  def sort_order
    if params[:user_where].present? || params[:location].present?
      "name"
    else
      "title"
    end
  end
end
