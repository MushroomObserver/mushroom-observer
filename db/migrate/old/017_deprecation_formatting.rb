# The purpose of this migration is to update all the names so their
# formating reflects whether they are deprecated or not.
class DeprecationFormatting < ActiveRecord::Migration
  def self.up
    for n in Name.find(:all)
      n.change_deprecated(n.deprecated)
      n.save
    end
  end

  def self.down
  end
end
