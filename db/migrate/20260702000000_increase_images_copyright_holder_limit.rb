# frozen_string_literal: true

# Widen images.copyright_holder from 100 to 255 chars. iNat's photo
# attribution strings (used as copyright_holder on import) can exceed 100
# chars, which raised a BadParameterValue during iNat image imports.
class IncreaseImagesCopyrightHolderLimit < ActiveRecord::Migration[7.2]
  def up
    change_column(:images, :copyright_holder, :string, limit: 255)
  end

  def down
    change_column(:images, :copyright_holder, :string, limit: 100)
  end
end
