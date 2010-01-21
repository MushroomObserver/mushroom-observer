class ExpandCitation < ActiveRecord::Migration
  def self.copy_column(table, src, dest)
    Comment.connection.update %(
      UPDATE #{table}
      SET #{dest} = #{src}
    )
  end
  
  def self.rename_column(table, src, dest, type)
    if type == :string
      add_column(table, dest, type, :limit => 200)
    else
      add_column(table, dest, type)
    end
    copy_column(table, src, dest)
    remove_column(table, src)
  end
  
  def self.update_column(table, src_column, type)
    dest_column = "#{src_column}_tmp"
    rename_column(table, src_column, dest_column, type)
    rename_column(table, dest_column, src_column, type)
  end

  def self.up
    update_column(:names, :citation, :text)
    update_column(:past_names, :citation, :text)
  end

  def self.down
    update_column(:names, :citation, :string)
    update_column(:past_names, :citation, :string)
  end
end
