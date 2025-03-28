# frozen_string_literal: true

class Query::Articles < Query::Base
  def model
    @model ||= Article
  end

  def list_by
    @list_by ||= Article[:title]
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [Article],
      title_has: :string,
      body_has: :string,
      by_users: [User]
    )
  end

  def initialize_flavor
    add_owner_and_time_stamp_conditions
    add_id_in_set_condition
    add_search_condition("articles.title", params[:title_has])
    add_search_condition("articles.body", params[:body_has])
    super
  end

  def self.default_order
    "created_at"
  end
end
