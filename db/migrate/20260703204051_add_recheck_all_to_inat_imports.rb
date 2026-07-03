# frozen_string_literal: true

# Whether an import-all / URL-mode run should re-check observations that
# already carry iNat's "Mushroom Observer URL" field instead of filtering
# them out server-side with without_field. Lets users re-import
# observations whose MO link is dead (MO observation deleted).
class AddRecheckAllToInatImports < ActiveRecord::Migration[7.2]
  def change
    add_column(:inat_imports, :recheck_all, :boolean,
               default: false, null: false)
  end
end
