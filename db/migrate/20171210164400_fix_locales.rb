class FixLocales < ActiveRecord::Migration
  def up
    User.connection.execute(%(
      UPDATE users
      SET locale = LEFT(locale, 2)
      WHERE locale LIKE "%-%"
    ))
    User.connection.execute(%(
      UPDATE name_descriptions
      SET locale = LEFT(locale, 2)
      WHERE locale LIKE "%-%"
    ))
    User.connection.execute(%(
      UPDATE location_descriptions
      SET locale = LEFT(locale, 2)
      WHERE locale LIKE "%-%"
    ))
    User.connection.execute(%(
      UPDATE users
      SET locale = "en"
      WHERE locale IS NULL
    ))
    User.connection.execute(%(
      UPDATE name_descriptions
      SET locale = "en"
      WHERE locale IS NULL
    ))
    User.connection.execute(%(
      UPDATE location_descriptions
      SET locale = "en"
      WHERE locale IS NULL
    ))
    remove_column :languages, :region
  end

  def down
    # Reverse migration probably won't work.
    add_column :languages, :region, :string, limit: 4
  end
end
