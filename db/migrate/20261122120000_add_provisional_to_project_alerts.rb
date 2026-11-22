# frozen_string_literal: true

# A project hears about a provisional or temporary code proposed on an
# observation it was told about, and the message words that case
# differently from a correction to another scientific name. Which one
# a row was is iNaturalist's `provisional` flag on the identification's
# taxon, read when the row is written: the identification is gone from
# memory by the time the digest renders.
class AddProvisionalToProjectAlerts < ActiveRecord::Migration[7.2]
  def change
    add_column(:project_alerts, :provisional, :boolean,
               default: false, null: false)
  end
end
