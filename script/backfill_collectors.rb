# frozen_string_literal: true

# Online pre-deploy backfill for #4211 / PR #4452 (the expand release).
#
# Seeds Observation#collector from the legacy notes keys with the site UP,
# ahead of the deploy. Only the collector / collector_user_id columns are
# written — invisible to the running code, which still displays collectors
# from notes (it dual-reads) — so running this online is safe. It does NOT
# strip notes or templates; that is the contract release's offline migration.
#
# Run against production (or a prod copy) with the expand-release code on
# disk:
#
#   bin/rails runner script/backfill_collectors.rb
#
# Idempotent — only fills rows whose collector column is still blank, so it
# is safe to re-run, and the contract migration re-runs it as a safety net.
reporter = Object.new
# Matches ActiveRecord::Migration#say(message, subitem) — positional.
def reporter.say(message, *args)
  puts(args.first ? "   #{message}" : message)
end

CollectorNotesSeeder.new(reporter: reporter).run
