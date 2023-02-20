# frozen_string_literal: true

# helper methods for Herbaria views
module HerbariaHelper
  def herbarium_top_users(herbarium)
    User.joins(:herbarium_records).
      where(HerbariumRecord[:id].eq(herbarium.id)).
      select(User[:name], User[:login], User[:id].count).
      group(User[:id]).order("COUNT(`users`.`id`) DESC").take(5)
  end
end
