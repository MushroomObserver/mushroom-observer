class StripRegionCodes < ActiveRecord::Migration
  def self.up
    add_column :languages, :region, :string, :limit => 4
    for l in Language.all
      l.locale, l.region = l.locale.split('-')
      l.save
      print "#{l.locale}, #{l.region}\n"
    end
  end

  def self.down
    for l in Language.all
      l.locale = "#{l.locale}-#{l.region}"
      l.save
      print "#{l.locale}\n"
    end
    remove_column :languages, :region
  end
end
