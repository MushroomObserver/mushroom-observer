class AdjustEnumDefaults < ActiveRecord::Migration[4.2]
  def up
    change_column_default :name_descriptions, :review_status, 1
    change_column_default :users, :thumbnail_size, 1
    change_column_default :users, :image_size, 3
    change_column_default :users, :votes_anonymous, 1
    change_column_default :users, :location_format, 1
    change_column_default :users, :hide_authors, 1
    change_column_default :users, :keep_filenames, 1
  end

  #  Although the schema itself is reversible, running this down migration
  #  will break the application unless one also redefines the enum numerical
  #  values in the models, and changes the values in the fixtures
  #  for +all+ enum attributes (not merely the ones in this migration).
  def down
    change_column_default :name_descriptions, :review_status, 0
    change_column_default :users, :thumbnail_size, 0
    change_column_default :users, :image_size, 0
    change_column_default :users, :votes_anonymous, 0
    change_column_default :users, :location_format, 0
    change_column_default :users, :hide_authors, 0
    change_column_default :users, :keep_filenames, 0
  end
end
