# encoding: utf-8
class AddOkForExportToNames < ActiveRecord::Migration[4.2]
  def self.up
    add_column :names, :ok_for_export, :boolean, null: false, default: true
    add_column :locations, :ok_for_export, :boolean, null: false, default: true
    add_column :location_descriptions, :ok_for_export, :boolean, null: false, default: true
    add_column :name_descriptions, :project_id, :integer
    add_column :location_descriptions, :project_id, :integer

    for desc in NameDescription.where(source_type: :project)
      project = Project.find_by_title(desc.source_name)
      Name.connection.update %(
        UPDATE name_descriptions SET project_id = #{project.id}
        WHERE id = #{desc.id}
      )
    end
  end

  def self.down
    remove_column :names, :ok_for_export
    remove_column :locations, :ok_for_export
    remove_column :location_descriptions, :ok_for_export
    remove_column :name_descriptions, :project_id
    remove_column :location_descriptions, :project_id
  end
end
