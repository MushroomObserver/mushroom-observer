# frozen_string_literal: true

# Alerting went to every admin of the project. Nobody asked for that, so
# a project now carries the list of users who have opted in, and an
# empty list sends nothing (#5416).
class AddAlertRecipientsToProjectExternalSites < ActiveRecord::Migration[7.2]
  def change
    add_column(:project_external_sites, :alert_recipient_ids, :text)
  end
end
