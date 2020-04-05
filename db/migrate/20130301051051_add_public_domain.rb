class AddPublicDomain < ActiveRecord::Migration[4.2]
  def self.up
    pd = License.new
    pd.display_name = "Public Domain"
    pd.url = "http://wiki.creativecommons.org/Public_domain/"
    pd.form_name = "publicdomain"
    pd.deprecated = false
    pd.save
  end

  def self.down
    pd = License.find_by_form_name("publicdomain")
    pd.destroy if pd
  end
end
