class UserCopyright < ActiveRecord::Migration
  def self.up
    add_column :images,  "copyright_holder", :string, :limit => 100
    # Populate with image.user.legal_name
    # Not sure this is really the right way to do this, but need to look up migrations on the web.
    for i in Image.find(:all)
      i.copyright_holder = i.user.legal_name
      i.save
    end
  end

  def self.down
    remove_column :images,  "copyright_holder"
  end
end
