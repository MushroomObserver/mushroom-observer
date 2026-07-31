# frozen_string_literal: true

# One machine-read of a field slip photo (see FieldSlipExtract /
# FieldSlip::Extractor). Unique on image_id: re-running an extraction
# replaces the previous read rather than accumulating versions, since
# only the latest is reviewed. `provider`/`model`/`prompt_version` are
# stored beside the data so a result can be attributed to the setup that
# produced it -- extraction is expected to change over time.
class CreateFieldSlipExtracts < ActiveRecord::Migration[7.2]
  def change
    create_table(:field_slip_extracts) do |t|
      t.integer(:image_id, null: false)
      t.integer(:user_id, null: false)
      t.string(:provider, null: false)
      t.string(:model, null: false)
      t.string(:prompt_version)
      t.json(:data)
      t.timestamps
    end
    add_index(:field_slip_extracts, :image_id, unique: true)
    add_index(:field_slip_extracts, :user_id)
  end
end
