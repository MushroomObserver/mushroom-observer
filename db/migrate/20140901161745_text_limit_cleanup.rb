class TextLimitCleanup < ActiveRecord::Migration
  def up
    change_column(:herbaria, :mailing_address, :text, limit: nil)
    change_column(:herbaria, :description, :text, limit: nil)
    change_column(:specimens, :notes, :text, limit: nil)
  end

  def down
  end
end
