#!/usr/bin/env ruby
# frozen_string_literal: true

# One-time, idempotent cleanup of 3 iNaturalist ExternalLinks whose external_id
# and url pointed at DIFFERENT iNat observations (surfaced by the #4565 audit).
# Each is resolved to a single iNat obs; the url is dropped so link_url derives
# from external_id. Safe to re-run: a link whose url is already blank is
# skipped, and one whose url no longer matches the anomaly is left untouched.
#
#   bin/rails runner script/fix_external_link_id_anomalies.rb         # dry run
#   APPLY=1 bin/rails runner script/fix_external_link_id_anomalies.rb # write

apply = ENV["APPLY"] == "1"
inat = ExternalSite.inaturalist

# id => { bad_url_id:, set_external_id?: }
# bad_url_id: the iNat obs id the (to-be-dropped) url currently points at.
# set_external_id: replace external_id first (only #12177, whose external_id obs
#   no longer exists on iNat — the url's obs is the real one).
fixes = {
  12_177 => { bad_url_id: "321059174", set_external_id: "321059174" },
  20_248 => { bad_url_id: "315497806" },
  39_149 => { bad_url_id: "314874936" }
}

fixes.each do |id, fix|
  link = ExternalLink.find_by(id: id)
  unless link
    warn("##{id}: not found, skipping")
    next
  end
  if link.url.blank?
    warn("##{id}: already fixed (url blank, external_id=#{link.external_id})")
    next
  end

  expected = inat.observation_url(fix[:bad_url_id])
  if link.url != expected
    warn("##{id}: url #{link.url.inspect} != recorded anomaly " \
         "#{expected.inspect}; skipping for safety")
    next
  end

  before = "external_id=#{link.external_id.inspect} url=#{link.url.inspect}"
  link.external_id = fix[:set_external_id] if fix[:set_external_id]
  link.url = nil
  link.save! if apply
  warn("##{id}: #{before} -> external_id=#{link.external_id.inspect} url=nil " \
       "#{apply ? "(applied)" : "(dry run)"}")
end

warn(apply ? "APPLIED." : "Dry run. Re-run with APPLY=1 to write.")
