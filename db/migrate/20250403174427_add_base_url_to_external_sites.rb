class AddBaseURLToExternalSites < ActiveRecord::Migration[7.2]
  def up
    add_column :external_sites, :base_url, :string, null: false
    ExternalSite.find(1).update(
      base_url: "https://www.mycoportal.org/portal/collections/"
    )
  end

  def down
    remove_column :external_sites, :base_url
  end
end
