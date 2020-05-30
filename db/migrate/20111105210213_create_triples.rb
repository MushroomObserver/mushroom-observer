class CreateTriples < ActiveRecord::Migration[4.2]
  def self.up
    create_table :triples, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.column "subject", :string, limit: 1024
      t.column "predicate", :string, limit: 1024
      t.column "object", :string, limit: 1024
    end
    lichen_list = SpeciesList.find_by_title("lichens")
    if lichen_list
      vals = lichen_list.observations.map do |o|
        "(':name/#{o.name_id}')"
      end.join(",")
      Triple.connection.insert(%(
        INSERT INTO triples (`subject`) VALUES #{vals}
      ))
      Triple.connection.update(%(
        UPDATE triples SET `predicate` = ':lichenAuthority',
          `object` = '"http://mushroomobserver.org/lichen_genera.txt"^^xsd:anyURI'
      ))
    end
  end

  def self.down
    drop_table :triples
  end
end
