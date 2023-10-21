# frozen_string_literal: true

# helper methods for Herbaria views
module HerbariaHelper
  def herbarium_top_users(herbarium_id)
    User.joins(:herbarium_records).
      where(herbarium_records: { herbarium_id: herbarium_id }).
      select(:name, :login, User[:id].count).
      group(:id).order(User[:id].count.desc).take(5)
  end
end
