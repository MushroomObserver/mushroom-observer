# frozen_string_literal: true

class AddNameLookupIndexes < ActiveRecord::Migration[7.2]
  # `names` had no index on either lookup column, so every exact-match
  # in name resolution -- run several times per naming proposal, plus
  # the alternate-spelling sweep's prefix guesses -- was a full table
  # scan at ~30-50ms each.
  def change
    add_index(:names, :text_name)
    add_index(:names, :search_name)
  end
end
