class MakeSurePublicDescriptionsArePublic < ActiveRecord::Migration[4.2]
  def up
    Name.connection.execute(%(
      UPDATE name_descriptions SET public = TRUE
      WHERE source_type = 1 AND public IS FALSE
    ))
    Location.connection.execute(%(
      UPDATE location_descriptions SET public = TRUE
      WHERE source_type = 1 AND public IS FALSE
    ))
  end

  def down
  end
end
