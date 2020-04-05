# encoding: utf-8

class FixNameOrderingAgain < ActiveRecord::Migration[4.2]
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
      expect_rank = Name.guess_rank(text_name)
      if rank.to_sym != expect_rank && rank != "Domain" && rank != "Kingdom"
        puts "#{id}: #{text_name.inspect} is #{rank}, should be #{expect_rank}"
      end
    end
    vals = data.map { |v| Name.connection.quote(v.to_s) }.join(",")
    Name.connection.update %(
      UPDATE names SET sort_name = ELT(id+1, #{vals})
    )
  end
end
