# frozen_string_literal: true

# #5416: a site's published rate limits, and the hosts it serves media
# from, are properties of the site rather than facts about iNaturalist
# that belong in Ruby. Storing them here means adding a second source
# (MyCoPortal, #4216) is a row rather than another hardcoded block in
# ExternalSiteUsage and the usage rake tasks.
#
# Nil means "no published limit" rather than zero, so a site MO has no
# agreement with is not treated as having a limit of none.
#
# The values seeded for iNaturalist come from its API description
# (https://api.inaturalist.org/v1/swagger.json: 100 requests/minute
# throttled, 60 asked, under 10,000/day) and its developers page
# (https://www.inaturalist.org/pages/developers: over 5 GB of media an
# hour or 24 GB a day "may result in a permanent block"). The per-minute
# figure recorded is the 60 iNat asks for, not the 100 it enforces.
class AddUsageLimitsToExternalSites < ActiveRecord::Migration[7.2]
  GIBIBYTE = 1024**3

  def up
    add_column(:external_sites, :requests_per_minute_limit, :integer)
    add_column(:external_sites, :requests_per_day_limit, :integer)
    add_column(:external_sites, :media_bytes_per_hour_limit, :bigint)
    add_column(:external_sites, :media_bytes_per_day_limit, :bigint)
    # Comma-separated hostnames; see ExternalSite#media_host_list.
    add_column(:external_sites, :media_hosts, :text)

    seed_inaturalist
  end

  def down
    remove_column(:external_sites, :requests_per_minute_limit)
    remove_column(:external_sites, :requests_per_day_limit)
    remove_column(:external_sites, :media_bytes_per_hour_limit)
    remove_column(:external_sites, :media_bytes_per_day_limit)
    remove_column(:external_sites, :media_hosts)
  end

  private

  def seed_inaturalist
    site = ExternalSite.find_by(name: ExternalSite::INATURALIST_NAME)
    return unless site

    site.update_columns(
      requests_per_minute_limit: 60,
      requests_per_day_limit: 10_000,
      media_bytes_per_hour_limit: 5 * GIBIBYTE,
      media_bytes_per_day_limit: 24 * GIBIBYTE,
      media_hosts: "static.inaturalist.org," \
                   "inaturalist-open-data.s3.amazonaws.com"
    )
  end
end
