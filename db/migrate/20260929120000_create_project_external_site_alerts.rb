# frozen_string_literal: true

# #5416 slice 4: what MO has already told a project's admins about, and
# how far the poll that finds it has reached.
#
# A row per project per identification on the external site, so that a
# later edit to an observation MO has already alerted on does not alert
# again. Kept indefinitely: the record of what was sent is worth more
# than the rows cost, and it is what a project's alerts subtab will
# show.
#
# The watermark is one column on `external_sites` rather than one per
# project. A single poll serves every alerting project, so it says
# where that poll has reached; which projects hear about a candidate is
# decided per cycle from which of them have alerting on.
class CreateProjectExternalSiteAlerts < ActiveRecord::Migration[7.2]
  def change
    add_column(:external_sites, :last_alert_poll_at, :datetime)

    create_table(:project_external_site_alerts, id: :integer,
                                                charset: "utf8mb3") do |t|
      t.integer(:project_id, null: false)
      t.integer(:external_site_id, null: false)

      # The site's ids, in its namespace rather than MO's, for the same
      # reason `project_external_sites.remote_project_id` is a string.
      t.string(:remote_identification_id, limit: 100, null: false)
      t.string(:remote_observation_id, limit: 100, null: false)

      # What was applied and when the mushroom was seen -- the two
      # things the message states, kept so a sent alert can be shown
      # later without asking iNat again.
      t.string(:name, limit: 255)
      t.date(:observed_on)

      t.datetime(:alerted_at)

      t.timestamps(null: true)

      t.index([:project_id, :external_site_id, :remote_identification_id],
              unique: true,
              name: "index_project_site_alerts_on_project_site_and_ident")
      t.index(:external_site_id)
    end
  end
end
