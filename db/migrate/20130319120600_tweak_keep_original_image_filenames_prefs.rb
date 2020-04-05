class TweakKeepOriginalImageFilenamesPrefs < ActiveRecord::Migration[4.2]
  def self.up
    rename_column(:users, :keep_filenames, :old_keep_filenames)
    add_column(:users, :keep_filenames, :enum, default: :keep_and_show, null: false, limit: [:toss, :keep_but_hide, :keep_and_show])
    User.connection.update %(
      UPDATE users SET keep_filenames = IF(old_keep_filenames, 'keep_but_hide', 'toss')
    )
    remove_column(:users, :old_keep_filenames)
  end

  def self.down
    rename_column(:users, :keep_filenames, :old_keep_filenames)
    add_column(:users, :keep_filenames, :boolean, default: true, null: false)
    User.connection.update %(
      UPDATE users SET keep_filenames = IF(old_keep_filenames == 'toss', false, true)
    )
    remove_column(:users, :old_keep_filenames)
  end
end
