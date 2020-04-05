# encoding: utf-8
class ConvertDatabaseToUtc < ActiveRecord::Migration[4.2]
  def self.up
    correct_datetimes("+")
  end

  def self.down
    correct_datetimes("-")
  end

  def self.correct_datetimes(sign)
    for table, cols in [
      ["comments", %w(created modified)],
      ["images", %w(created modified last_view)],
      ["interests", ["modified"]],
      ["licenses", ["modified"]],
      ["location_descriptions", %w(created modified last_view)],
      ["location_descriptions_versions", ["modified"]],
      ["locations", %w(created modified last_view)],
      ["locations_versions", ["modified"]],
      ["name_descriptions", %w(created modified last_review last_view)],
      ["name_descriptions_versions", ["modified"]],
      ["names", %w(created modified last_view)],
      ["names_versions", ["modified"]],
      ["namings", %w(created modified)],
      ["notifications", ["modified"]],
      ["observations", %w(created modified last_view)],
      ["projects", %w(created modified)],
      ["rss_logs", ["modified"]],
      ["species_lists", %w(created modified)],
      ["user_groups", %w(created modified)],
      ["users", %w(created last_login verified modified)],
      ["votes", %w(created modified)]
    ]
      for col in cols
        correct_column(table, col, sign)
      end
    end
  end

  def self.correct_column(table, col, sign)
    puts "Correcting #{table}.#{col}..."
    User.connection.update %(
      UPDATE #{table} SET #{col} = #{col} #{sign} INTERVAL
        IF(#{col} < '2006-10-29 08:26:23', 7,
        IF(#{col} < '2007-03-11 10:21:03', 8,
        IF(#{col} < '2007-10-28 07:12:21', 7,
        IF(#{col} < '2007-10-30 16:37:38', 8,
        IF(#{col} < '2007-11-04 16:28:04', 7,
        IF(#{col} < '2008-03-09 03:21:03', 8,
        IF(#{col} < '2008-11-02 01:46:14', 7,
        IF(#{col} < '2009-03-08 03:33:35', 8,
        IF(#{col} < '2009-11-01 03:05:59', 7,
        IF(#{col} < '2009-12-07 18:17:12', 8,
        IF(#{col} < '2010-03-14 03:11:10', 5, 4))))))))))) HOUR
      WHERE #{col} IS NOT NULL
    )
  end
end
