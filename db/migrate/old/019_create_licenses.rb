class CreateLicenses < ActiveRecord::Migration
  def self.up
    create_table :licenses, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :force => true do |t|
      t.column "display_name", :string, :limit => 80
      t.column "url", :string, :limit => 200
      t.column "deprecated", :boolean, :default => false, :null => false
      t.column "form_name", :string, :limit => 20
    end

    ccnc25 = License.new
    ccnc25.display_name = "Creative Commons Non-commercial v2.5"
    ccnc25.url = 'http://creativecommons.org/licenses/by-nc-sa/2.5/'
    ccnc25.deprecated = true
    ccnc25.form_name = 'ccbyncsa25'
    ccnc25.save

    ccnc30 = License.new
    ccnc30.display_name = "Creative Commons Non-commercial v3.0"
    ccnc30.url = 'http://creativecommons.org/licenses/by-nc-sa/3.0/'
    ccnc30.deprecated = false
    ccnc30.form_name = 'ccbyncsa30'
    ccnc30.save

    ccwiki30 = License.new
    ccwiki30.display_name = "Creative Commons Wikipedia Compatible v3.0"
    ccwiki30.url = 'http://creativecommons.org/licenses/by-sa/3.0/'
    ccwiki30.deprecated = false
    ccwiki30.form_name = 'ccbysa30'
    ccwiki30.save

    add_column :images, "license_id", :integer, :default => ccnc25.id, :null => false
    add_column :users, "license_id", :integer, :default => ccwiki30.id, :null => false
  end

  def self.down
    remove_column :users, "license_id"
    remove_column :images, "license_id"
    drop_table :licenses
  end
end
