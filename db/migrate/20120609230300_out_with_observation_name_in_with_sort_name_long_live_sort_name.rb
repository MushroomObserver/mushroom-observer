# encoding: utf-8

class OutWithObservationNameInWithSortNameLongLiveSortName < ActiveRecord::Migration[4.2]
  def self.up
    rename_column(:names, :observation_name, :sort_name)
    rename_column(:names_versions, :observation_name, :sort_name)
    Name.connection.update %(
      UPDATE names SET sort_name = REPLACE(TRIM(LEADING '"' FROM COALESCE(search_name,'')), ' "', ' ')
    )
    Name.connection.update %(
      UPDATE names_versions SET sort_name = REPLACE(TRIM(LEADING '"' FROM COALESCE(search_name,'')), ' "', ' ')
    )
  end

  def self.down
  end
end
