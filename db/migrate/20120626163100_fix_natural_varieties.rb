# encoding: utf-8

class FixNaturalVarieties < ActiveRecord::Migration[4.2]
  def self.up
    for id, text_name in Name.connection.select_rows %(
      SELECT id, text_name FROM names
      WHERE rank in ('Subspecies', 'Variety', 'Form')
        AND COALESCE(author, '') != ''
    )
      words = text_name.split(" ")
      if words[-3] == words[-1]
        name = Name.find(id)
        new_display_name = Name.format_natural_variety(name.text_name, name.author, name.rank, name.deprecated)
        $stdout.write("\r" + (" " * 79) + "\r" + new_display_name)
        $stdout.flush
        Name.connection.update %(
          UPDATE names SET display_name = #{Name.connection.quote(new_display_name)} WHERE id = #{id}
        )
      end
    end
  end

  def self.down
  end
end
