class EolNameTweaks < ActiveRecord::Migration
  def self.up

    add_column :names, "license_id", :integer
    add_column :names, "ok_for_export", :boolean, :default => true, :null => false
    add_column :past_names, "license_id", :integer
    add_column :past_names, "ok_for_export", :boolean, :default => true, :null => false
    add_column :draft_names, "license_id", :integer
    add_column :past_draft_names, "license_id", :integer

    for n in Name.find(:all)
      user = n.user
      if user
        if n.has_any_notes?
          Name.connection.update("UPDATE names SET license_id = #{user.license_id} WHERE id = #{n.id}")
        end
      end
    end
    for n in DraftName.find(:all)
      user = n.user
      if user
        if n.has_any_notes?
          DraftName.connection.update("UPDATE draft_names SET license_id = #{user.license_id} WHERE id = #{n.id}")
        end
      end
    end
  end

  def self.down
    remove_column :names, "license_id"
    remove_column :names, "ok_for_export"
    remove_column :past_names, "license_id"
    remove_column :past_names, "ok_for_export"
    remove_column :draft_names, "license_id"
    remove_column :past_draft_names, "license_id"
  end
end
