class AddFilterPrefsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :filter_prefs, :string, default: { }.to_yaml
  end
end
