class StripRegionCodes < ActiveRecord::Migration[4.2]
  def self.up
    add_column :languages, :region, :string, limit: 4
    for l in Language.all
      l.locale, l.region = l.locale.split("-")
      l.save
    end
  end

  def self.down
    for l in Language.all
      l.locale = "#{l.locale}-#{l.region}"
      l.save
    end
    remove_column :languages, :region
  end
end
