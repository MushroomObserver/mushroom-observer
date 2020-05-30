class UnboldAllDeprecatedNames < ActiveRecord::Migration[4.2]
  def up
    Name.connection.select_rows(%(
      SELECT id, display_name FROM names
      WHERE deprecated IS TRUE AND display_name LIKE "%*%"
    )).each do |id, str|
      puts "Fixing #{id} #{str}"
      str.gsub!(/\*\*([^*]+)\*\*/, '\1')
      str = Name.connection.quote(str)
      Name.connection.execute(%(
        UPDATE names SET display_name = #{str} WHERE id = #{id}
      ))
    end
  end

  def down
  end
end
