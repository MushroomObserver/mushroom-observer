class PopulateVisualGroups < ActiveRecord::Migration[6.1]
  def up
    for group in Name.where(rank: 16)
      name = Name.find_by(text_name: group.text_name.split[0..-2].join(" "))
      next unless name
      name.visual_group = VisualGroup.create(name_id: name.id)
      name.save
    end
  end

  def down
    VisualGroup.delete_all
  end
end
