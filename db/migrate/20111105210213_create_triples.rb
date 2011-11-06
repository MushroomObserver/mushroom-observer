class CreateTriples < ActiveRecord::Migration
  def self.up
    create_table :triples do |t|
      t.column "subject", :string, :limit => 1024
      t.column "predicate", :string, :limit => 1024
      t.column "object", :string, :limit => 1024
    end
    lichen_list = SpeciesList.find_by_title("lichens")
    if lichen_list
      ids = Set.new(lichen_list.observations.map {|o| o.name_id})
      ids.each do |id|
        Triple.create(:subject => ":name/#{id}", :predicate => ":lichenAuthority", :object => '"http://www.ndsu.edu/pubweb/~esslinge/chcklst/chcklst7.htm"^^xsd:anyURI')
      end
    end
  end

  def self.down
    drop_table :triples
  end
end
