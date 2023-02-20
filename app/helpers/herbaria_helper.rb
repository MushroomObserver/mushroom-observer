# frozen_string_literal: true

# helper methods for Herbaria views
module HerbariaHelper
  def herbarium_top_users(herbarium)
    User.joins(:herbarium_records).
      where(HerbariumRecord[:herbarium_id].eq(herbarium.id)).
      select(User[:name], User[:login], User[:id].count).
      group(User[:id]).order(User[:id].count.desc).take(5)
  end
end
