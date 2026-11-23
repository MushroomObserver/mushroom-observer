# frozen_string_literal: true

# Alert subscriptions belong to a project rather than to one of its
# external sites (#5721). An admin who asked to hear about a matching
# observation wants to hear whichever source it came from, and MO is a
# source with no row in project_external_sites to carry the flag.
#
# `alerting` goes with them. A project alerts when one of its admins
# has subscribed, so the site-admin flag that gated the rollout has
# nothing left to say.
#
# Down restores the columns but not the per-site split, which a merged
# list no longer records.
class MoveProjectAlertSubscriptionsToProjects < ActiveRecord::Migration[7.2]
  # Copies of the tables as this migration needs them, rather than the
  # application's models -- those go on changing after this is written.
  class MigrationProject < ActiveRecord::Base
    self.table_name = "projects"
  end

  class MigrationProjectExternalSite < ActiveRecord::Base
    self.table_name = "project_external_sites"
  end

  def up
    add_column(:projects, :alert_recipient_ids, :text)
    move_subscriptions
    change_table(:project_external_sites, bulk: true) do |t|
      t.remove(:alerting, :alert_recipient_ids)
    end
  end

  def down
    change_table(:project_external_sites, bulk: true) do |t|
      t.boolean(:alerting, default: false, null: false)
      t.text(:alert_recipient_ids)
    end
    remove_column(:projects, :alert_recipient_ids)
  end

  private

  # A project's subscribers are the union across its sites, so a
  # project whose two sites carry different admins keeps both.
  def move_subscriptions
    MigrationProjectExternalSite.where.not(alert_recipient_ids: nil).
      group_by(&:project_id).each do |project_id, sites|
        ids = sites.flat_map { |site| parse_ids(site.alert_recipient_ids) }
        next if ids.empty?

        MigrationProject.where(id: project_id).
          update_all(alert_recipient_ids: ids.uniq.to_json)
      end
  end

  def parse_ids(value)
    parsed = JSON.parse(value.to_s)
    parsed.is_a?(Array) ? parsed : []
  rescue JSON::ParserError
    []
  end
end
