# frozen_string_literal: true

# #5416 slice 2: a project's relationship with an external site -- what
# MO already holds from it, and, where MO can act, where the project's
# observations may come from and what MO may do about them.
#
# A row per project per site rather than columns on `projects`, because
# the exchange is with a site: MyCoPortal (#4216) is a second site with
# a different access pattern. Columns on `projects` would have to be
# prefixed per site and re-added for the next one.
#
# Source shape and action are orthogonal, which the issue's history got
# wrong twice. A rare challenge is selective through its constraints, so
# they find its observations; a foray sets none beyond a state-sized box
# and 8 days, so constraints would propose 10,989 candidates to find the
# 4,583 wanted and only a sister iNat project separates participants
# from the public. Either shape can feed alerting, importing, or both,
# so the two are recorded independently rather than as one enum.
#
# Nothing reads these columns yet. This slice is the configuration and
# its page; the preview that makes a configuration legible is next, and
# the cycle that acts on it comes after that.
class CreateProjectExternalSites < ActiveRecord::Migration[7.2]
  def change
    create_table(:project_external_sites, id: :integer,
                                          charset: "utf8mb3") do |t|
      t.integer(:project_id, null: false)
      t.integer(:external_site_id, null: false)

      # The site's identifier for a sister collection -- an iNat project
      # id. A string rather than an integer because it is the remote
      # site's namespace, not MO's: iNat numbers its projects, and
      # another site may not. The name is stored alongside it so the
      # page can show what the id means without asking iNat on every
      # render.
      t.string(:remote_project_id, limit: 100)
      t.string(:remote_project_name, limit: 255)

      # Consider only observations meeting the project's constraints --
      # whichever of target names, target locations, the area of its
      # location and its dates the project sets.
      t.boolean(:use_constraints, null: false, default: false)

      # What MO may do with what the site returns.
      t.boolean(:alerting, null: false, default: false)
      t.boolean(:importing, null: false, default: false)

      # A lifetime ceiling, so a misconfigured site cannot quietly
      # import forever. Deliberately not a rate: the worry is total
      # volume reaching MO, not the speed it arrives at.
      t.integer(:import_limit, null: false, default: 10_000)

      t.timestamps(null: true)

      t.index([:project_id, :external_site_id],
              unique: true,
              name: "index_project_sites_on_project_and_site")
      t.index(:external_site_id)
    end
  end
end
