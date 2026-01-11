class AddInatSearchURLToInatImports < ActiveRecord::Migration[7.2]
  def change
    add_column(:inat_imports, :inat_search_url, :text)
  end
end
