class RespaceNameRanks < ActiveRecord::Migration[7.2]
  OLD_TO_NEW = {
    1  => 100,  # Form
    2  => 200,  # Variety
    3  => 300,  # Subspecies
    4  => 400,  # Species
    5  => 420,  # Stirps
    6  => 440,  # Subsection
    7  => 460,  # Section
    8  => 480,  # Subgenus
    9  => 500,  # Genus
    10 => 600,  # Family
    11 => 700,  # Order
    12 => 800,  # Class
    13 => 900,  # Phylum
    14 => 1000, # Kingdom
    15 => 1100, # Domain
    16 => 410   # Group (moved below Genus)
  }.freeze

  def up
    ActiveRecord::Base.transaction do
      OLD_TO_NEW.each do |old_val, new_val|
        execute("UPDATE names SET `rank` = #{new_val} WHERE `rank` = #{old_val}")
        execute("UPDATE name_versions SET `rank` = #{new_val} WHERE `rank` = #{old_val}")
      end
    end
  end

  def down
    ActiveRecord::Base.transaction do
      OLD_TO_NEW.each do |old_val, new_val|
        execute("UPDATE names SET `rank` = #{old_val} WHERE `rank` = #{new_val}")
        execute("UPDATE name_versions SET `rank` = #{old_val} WHERE `rank` = #{new_val}")
      end
    end
  end
end
