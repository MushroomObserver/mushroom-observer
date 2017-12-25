class MakeQueuedEmailFlavorLonger < ActiveRecord::Migration
  def up
    change_column :queued_emails, :flavor, :string, limit: 50
  end

  def down
  end
end
