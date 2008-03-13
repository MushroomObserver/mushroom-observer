class RemoveKingdom < ActiveRecord::Migration
  def self.up
    name = Name.find_by_display_name('Kingdom of **__Fungi__**')
    if name
      name.display_name = '**__Fungi__**'
      name.save
    end
  end

  def self.down
    name = Name.find_by_display_name('**__Fungi__**')
    if name
      name.display_name = 'Kingdom of **__Fungi__**'
      name.save
    end
  end
end
