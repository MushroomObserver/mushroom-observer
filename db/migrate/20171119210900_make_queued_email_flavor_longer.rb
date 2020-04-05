class MakeQueuedEmailFlavorLonger < ActiveRecord::Migration[4.2]
  def up
    change_column :queued_emails, :flavor, :string, limit: 50
  end

  def down
  end
end
