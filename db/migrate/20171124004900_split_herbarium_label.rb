class SplitHerbariumLabel < ActiveRecord::Migration
  def up
    add_column :herbarium_records, :initial_det, :string, null: false, limit: 221
    add_column :herbarium_records, :accession_number, :string, null: false, limit: 80
    Name.connection.execute(%(
      UPDATE herbarium_records
      SET accession_number = TRIM(herbarium_label)
      WHERE herbarium_label NOT REGEXP ":"
    ))
    Name.connection.execute(%(
      UPDATE herbarium_records
      SET
        initial_det = TRIM(LEFT(herbarium_label, LOCATE(":", herbarium_label) - 1)),
        accession_number = TRIM(RIGHT(herbarium_label, LENGTH(herbarium_label) - LOCATE(": ", herbarium_label) - 1))
      WHERE herbarium_label REGEXP ":"
    ))
    Name.connection.select_rows(%(
      SELECT id, herbarium_label
      FROM herbarium_records
      WHERE initial_det REGEXP "  " OR accession_number REGEXP ":|  "
    )).each do |id, label|
      match = label.match(/(.*):([^:]*)$/)
      if match
        left  = match[1].to_s.strip.squeeze(" ")
        right = match[2].to_s.strip.squeeze(" ")
      else
        left  = ""
        right = label.to_s.strip.squeeze(" ")
      end
      left  = Name.connection.quote(left)
      right = Name.connection.quote(right)
      Name.connection.execute(%(
        UPDATE herbarium_records
        SET initial_det = #{left}, accession_number = #{right}
        WHERE id = #{id}
      ))
    end
    remove_column :herbarium_records, :herbarium_label
  end

  def down
    add_column :herbarium_records, :herbarium_label, :string, null: false, limit: 80
    Name.connection.execute(%(
      UPDATE herbarium_records
      SET herbarium_label = CONCAT(initial_det, ": ", accession_number)
    ))
    remove_column :herbarium_records, :initial_det
    remove_column :herbarium_records, :accession_number
  end
end
