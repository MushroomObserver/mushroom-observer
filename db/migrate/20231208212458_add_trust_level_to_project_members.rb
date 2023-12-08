class AddTrustLevelToProjectMembers < ActiveRecord::Migration[6.1]
  def up
    add_column :project_members, :trust_level, :integer, default: 1, null: false
    ProjectMember.all.find_each do |pm|
      pm.update!(trust_level: "hidden_gps") if pm.trusted
    end
    remove_column :project_members, :trusted, :boolean, default: false, null: false
  end

  def down
    add_column :project_members, :trusted, :boolean, default: false, null: false
    ProjectMember.all.find_each do |pm|
      pm.update!(trusted: pm.trust_level != "no_trust")
    end
    remove_column :project_members, :trust_level, :integer, default: 1, null: false
  end
end
