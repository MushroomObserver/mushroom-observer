class FixUserLocales < ActiveRecord::Migration
  def up
    Language.all.each do |lang|
      User.connection.execute(%(
        UPDATE users
        SET users.locale = #{User.connection.quote(lang.locale_region)}
        WHERE users.locale = #{User.connection.quote(lang.locale)}
      ))
    end
    User.connection.execute(%(
      UPDATE users
      SET users.locale = "en-US"
      WHERE users.locale IS NULL
    ))
  end

  def down
  end
end
