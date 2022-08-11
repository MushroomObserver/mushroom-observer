class AddPrimaryKeyToImagesProjects < ActiveRecord::Migration[6.1]
  def change
    rename_table("images_projects", "project_images")
    add_column(:project_images, :id, :primary_key)
  end
end
