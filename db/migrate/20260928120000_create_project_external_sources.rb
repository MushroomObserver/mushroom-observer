# frozen_string_literal: true

# #5416 slice 2: where a project's observations may come from, and what
# MO is allowed to do about them.
#
# A row per project per external site rather than columns on `projects`,
# because the exchange is with a site: MyCoPortal (#4216) is a second
# source with a different access pattern, and a project may eventually
# draw on both. Columns on `projects` would have to be prefixed per site
# and re-added for the next one.
#
# Source shape and action are orthogonal, which the issue's history got
# wrong twice. A rare challenge is selective through its target names, so
# criteria find its observations; a foray has no target names and only a
# state-sized box, so criteria would propose 10,989 candidates to find
# the 4,583 wanted and only a sister iNat project separates participants
# from the public. Either source can feed alerting, importing, or both,
# so the two are recorded independently rather than as one enum.
#
# Nothing reads these columns yet. This slice is the configuration and
# its form; the preview that makes a configuration legible is next, and
# the cycle that acts on it comes after that.
class CreateProjectExternalSources < ActiveRecord::Migration[7.2]
  def change
    create_table(:project_external_sources, id: :integer,
                                            charset: "utf8mb3") do |t|
      t.integer(:project_id, null: false)
      t.integer(:external_site_id, null: false)

      # The site's identifier for a sister collection -- an iNat project
      # id. A string rather than an integer because it is the remote
      # site's namespace, not MO's: iNat numbers its projects, and
      # another site may not.
      t.string(:remote_project_id, limit: 100)

      # Derive the query from what the project already declares: target
      # names, target locations, the box on its location, and its dates.
      t.boolean(:use_criteria, null: false, default: false)

      # What MO may do with what the source returns. Both stay false
      # until a site admin approves the project, which the model
      # enforces.
      t.boolean(:alerting, null: false, default: false)
      t.boolean(:importing, null: false, default: false)

      # Site-admin approval, per #5416's rollout section: support any
      # interested project eventually, but start narrow, because rare
      # challenges are not representative of what a project asks for.
      t.datetime(:approved_at)
      t.integer(:approved_by_id)

      # A lifetime ceiling, so a misconfigured source cannot quietly
      # import forever. Deliberately not a rate: the worry is total
      # volume reaching MO, not the speed it arrives at.
      t.integer(:import_limit, null: false, default: 10_000)

      t.timestamps(null: true)

      t.index([:project_id, :external_site_id],
              unique: true,
              name: "index_project_sources_on_project_and_site")
      t.index(:external_site_id)
    end
  end
end
