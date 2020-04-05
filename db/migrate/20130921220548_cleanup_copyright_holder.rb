class CleanupCopyrightHolder < ActiveRecord::Migration[4.2]
  def self.up
    for current, preferred in Image.connection.select_rows %(
      SELECT DISTINCT i.copyright_holder, u.name
      FROM images i, users u
      WHERE i.user_id = u.id
      AND i.copyright_holder COLLATE utf8_bin != u.name
      AND u.name != ""
      AND i.copyright_holder = u.login
    )
      fix_copyright_holder(current, preferred)
    end
    fix_copyright_holder("debbie viess", "Debbie Viess")
    fix_copyright_holder("Johann Harnisch", "Johannes Harnisch")
  end

  def self.fix_copyright_holder(current, preferred)
    Image.connection.update %(
      UPDATE images SET copyright_holder = '#{preferred}' WHERE copyright_holder COLLATE utf8_bin = '#{current}'
      )
  end

  def self.down
  end
end
