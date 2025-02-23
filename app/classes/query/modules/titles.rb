# frozen_string_literal: true

# Deal with titles.
module Query::Modules::Titles
  attr_accessor :title_tag, :title_args

  def initialize_title
    @title_tag = :query_title_all
    @title_args = { type: model.to_s.underscore.to_sym }
  end

  def title
    initialize_query unless initialized?
    @title_tag.t(params.merge(@title_args))
  end

  # Add sort order to title of "all" queries.
  def add_sort_order_to_title
    return unless params[:by]

    self.title_tag = :query_title_all_by
    title_args[:order] = :"sort_by_#{params[:by].to_s.sub(/^reverse_/, "")}"
  end
end
