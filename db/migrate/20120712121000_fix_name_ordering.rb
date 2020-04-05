# encoding: utf-8

class FixNameOrdering < ActiveRecord::Migration[4.2]
  def self.up
    redo_sort_names
  end

  def self.down
  end

  def self.redo_sort_names
    data = []
    for id, rank, text_name, author, sort_name in Name.connection.select_rows %(
      SELECT id, rank, text_name, author, sort_name FROM names
    )
      data[id.to_i] = if rank == "Group"
                        Name.format_sort_name(text_name.sub(/ group$/, ""), "group")
                      else
                        Name.format_sort_name(text_name, author)
      end
    end
    vals = data.map { |v| Name.connection.quote(v.to_s) }.join(",")
    Name.connection.update %(
      UPDATE names SET sort_name = ELT(id+1, #{vals})
    )
  end
end
