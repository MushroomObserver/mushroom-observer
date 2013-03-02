class AddPublicDomain < ActiveRecord::Migration
  def self.up
    pd = License.new
    pd.display_name = "Public Domain"
    pd.url = 'http://wiki.creativecommons.org/Public_domain/'
    pd.form_name = 'publicdomain'
    pd.deprecated = false
    pd.save
  end

  def self.down
    pd = License.find_by_form_name('publicdomain')
    if pd
      pd.destroy
    end
  end
end
