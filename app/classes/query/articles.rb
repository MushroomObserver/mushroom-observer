# frozen_string_literal: true

class Query::Articles < Query::Base
  def model
    Article
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      by_users: [User],
      ids: [Article],
      title_has: :string,
      body_has: :string
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    add_owner_and_time_stamp_conditions
    add_ids_condition
    add_search_condition("articles.title", params[:title_has])
    add_search_condition("articles.body", params[:body_has])
    super
  end

  def self.default_order
    "created_at"
  end
end
