# frozen_string_literal: true

# helper methods for Herbaria views
module HerbariaHelper
  def herbarium_top_users(herbarium)
    Herbarium.connection.select_rows(%(
      SELECT u.name, u.login, COUNT(u.id)
      FROM herbarium_records hr JOIN users u ON u.id = hr.user_id
      WHERE hr.herbarium_id = #{herbarium.id}
      GROUP BY u.id ORDER BY COUNT(u.id) DESC LIMIT 5
    ))
  end
end
