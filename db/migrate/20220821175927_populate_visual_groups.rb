# frozen_string_literal: true

class PopulateVisualGroups < ActiveRecord::Migration[6.1]
  def up
    Name.where(rank: :Group).each do |group|
      next if group.visual_group.present?

      group_name = group.text_name.split[0..-2].join(" ")
      group_name = group.text_name if group_name == ""
      existing_group = VisualGroup.find_by(name: group_name)
      if existing_group
        existing_group.add_name(group)
      else
        vg = VisualGroup.create(name: group_name.to_s)
        vg.add_names(Name.where(text_name: group.text_name))
        vg.add_names(Name.where(text_name: group_name))
      end
    end
  end

  def down
    VisualGroup.delete_all
  end
end
