# frozen_string_literal: true

class PopulateVisualGroups < ActiveRecord::Migration[6.1]
  def up
    Name.where(rank: :Group).each do |group|
      next if group.visual_group.present?

      best_group = find_largest_group(group)
      vg = VisualGroup.create(group_name: best_group)
      vg.add_names(Name.where(text_name: best_group.text_name))
      species_name = best_group.text_name.split[0..-2].join(" ")
      vg.add_names(Name.where(text_name: species_name))
    end
  end

  def find_largest_group(group)
    groups = Name.where(text_name: group.text_name, rank: :Group)
    return largest_group(groups) if groups.count > 1

    group
  end

  def largest_group(groups)
    largest_group = nil
    count = 0
    groups.each do |name|
      name_count = name.observations.count
      if count < name_count
        largest_group = name
        count = name_count
      end
    end
    largest_group
  end

  def down
    VisualGroup.delete_all
  end
end
