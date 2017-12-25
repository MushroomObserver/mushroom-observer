class AddLifeformToNames < ActiveRecord::Migration
  def up
    add_column :names, :lifeform, :string, limit: 1024, null: false, default: " "
    add_column :names_versions, :lifeform, :string, limit: 1024, null: false, default: " "
    Name.connection.execute("UPDATE names SET lifeform = ' '")
    Name.connection.execute("UPDATE names_versions SET lifeform = ' '")
    data = read_lifeforms_data_file
    Name.all_lifeforms.each do |lifeform|
      puts "populating #{lifeform}..."
      ids = ids_of_names_with_lifeform(data, lifeform)
      populate_database_with_lifeform(ids, lifeform) if ids.any?
    end
  end

  def read_lifeforms_data_file
    puts "reading lichen genera..."
    file = "#{::Rails.root}/public/lifeforms.txt"
    data = {}
    File.readlines(file).each do |line|
      line.chomp!
      next if line =~ /^#/
      next if line !~ /\S/
      genus, lifeforms = line.split(" ", 2)
      data[genus] = " #{lifeforms} "
    end
    data
  end

  def ids_of_names_with_lifeform(data, lifeform)
    ids = []
    search_spec = " #{lifeform} "
    Name.connection.select_rows(%(
      SELECT id, text_name FROM names
    )).each do |id, text_name|
      genus = text_name.split(" ", 2).first
      ids << id.to_s if data[genus].to_s.include?(search_spec)
    end
    ids
  end

  def populate_database_with_lifeform(ids, lifeform)
    Name.connection.execute(%(
      UPDATE names SET lifeform = CONCAT(lifeform, "#{lifeform} ")
      WHERE id IN (#{ids.join(",")})
    ))
  end

  def down
    remove_column :names, :lifeform
    remove_column :names_versions, :lifeform
  end
end
