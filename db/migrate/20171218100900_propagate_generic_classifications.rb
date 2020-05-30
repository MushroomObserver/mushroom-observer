class PropagateGenericClassifications < ActiveRecord::Migration[4.2]
  def up
    puts "Refresh classification for genera from descriptions..."
    Name.connection.execute(%(
      UPDATE names n, name_descriptions nd
      SET n.classification = nd.classification
      WHERE nd.id = n.description_id
        AND n.rank = #{Name.ranks[:Genus]}
        AND nd.classification != n.classification
    ))

    puts "Grabbing all genera with classifications..."
    genera = {}
    Name.where(rank: Name.ranks[:Genus], correct_spelling_id: nil).each do |name|
      next if name.classification.blank?
      genera[name.text_name] ||= []
      genera[name.text_name] << name
    end

    puts "Choosing best name to use for each genus..."
    best = {}
    genera.each do |genus, names|
      names.reject!(&:deprecated) unless names.all?(&:deprecated)
      if names.count > 1
        names.sort_by! do |n|
          Name.connection.select_value(%(
            SELECT COUNT(id) FROM observations WHERE name_id = #{n.id}
          )).to_i * -1
        end
      end
      best[names.first.text_name] = names.first
    end

    puts "Creating map from subtaxa to genus..."
    rows = []
    Name.where(correct_spelling_id: nil).each do |name|
      next unless name.below_genus?
      genus = best[name.text_name.split(" ", 2).first]
      rows << [name.id, genus.id] if genus
    end

    puts "Creating temporary table..."
    create_table :temp, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.integer :name_id
      t.integer :genus_id
    end
    Name.connection.execute(%(
      INSERT INTO temp (name_id, genus_id) VALUES
      #{ rows.map { |r| "(#{r[0]},#{r[1]})" }.join(",\n") }
    ))

    puts "Propagating generic classifications..."
    Name.connection.execute(%(
      UPDATE names n1, temp t, names n2
      SET n1.classification = n2.classification
      WHERE n1.rank > #{Name.ranks[:Genus]}
        AND t.name_id = n1.id
        AND n2.id = t.genus_id
    ))

    puts "Dropping temporary table..."
    drop_table :temp

    puts "Pushing classifications for subtaxa to descriptions..."
    Name.connection.execute(%(
      UPDATE names n, name_descriptions nd
      SET nd.classification = n.classification
      WHERE nd.id = n.description_id
        AND COALESCE(n.classification, "") != ""
        AND n.rank > #{Name.ranks[:Genus]}
    ))

    puts "Refreshing observation cache..."
    Observation.connection.execute(%(
      UPDATE observations o, names n
      SET o.classification = n.classification
      WHERE o.name_id = n.id
        AND o.classification != n.classification
    ))
  end

  def down
  end
end
