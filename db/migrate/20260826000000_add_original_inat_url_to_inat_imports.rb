# frozen_string_literal: true

# Persists the user's literal iNat search URL alongside the normalized
# inat_url query string, so a reimport link (built from a persisted
# InatImport, not request params) can repopulate the "search URL" field
# with a complete, resubmittable URL instead of reconstructing one and
# guessing which iNat host (UI vs API) it came from.
class AddOriginalInatURLToInatImports < ActiveRecord::Migration[7.2]
  def change
    add_column(:inat_imports, :original_inat_url, :text)
  end
end
