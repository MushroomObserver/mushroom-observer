# frozen_string_literal: true

# Singleton high-water mark for ImageGapDetectorJob (see
# ImageGapCheckpoint / Image::Processor::GapDetector). Schema only -- the
# row is created lazily and initialized on deploy via
# `ImageGapCheckpoint.reset_to(<id>)`.
class CreateImageGapCheckpoints < ActiveRecord::Migration[7.2]
  def change
    create_table(:image_gap_checkpoints) do |t|
      t.bigint(:last_verified_image_id, null: false, default: 0)
      t.timestamps
    end
  end
end
