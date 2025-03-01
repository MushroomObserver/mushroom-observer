# frozen_string_literal: true

class Query::ScopeClasses::Articles < Query::BaseAR
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
    add_id_in_set_condition
    add_simple_search_condition(:title)
    add_simple_search_condition(:body)
    super
  end

  def self.default_order
    :created_at
  end
end
