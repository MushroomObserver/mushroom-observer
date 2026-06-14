#!/usr/bin/env ruby
# frozen_string_literal: true

#  USAGE::
#
#    script/audit_inat_imports.rb [--sample N] [--ids 1,2,3] \
#                                 [--seed S] [--out PATH]
#
#  DESCRIPTION::
#
#    Read-only discovery audit for issue #4213. For a set of iNat-imported
#    MO observations it compares three reference points per field:
#
#      import  - the iNat values captured at import time, parsed from the
#                stored `iNat_imported_data` snapshot in the obs notes.
#      mo      - the observation's CURRENT MO attributes.
#      inat    - the source observation's CURRENT state, freshly fetched
#                from the iNat API (public/unauthenticated).
#
#    Comparing mo-vs-import localizes edits made ON MO after import;
#    comparing inat-vs-import localizes changes made ON iNat since import.
#    (notes/image-set lack a separate import baseline, so those diffs are
#    mo-vs-inat only and can't be attributed to a side - flagged as such.)
#
#    Diff cells are tri-state: true (differs), false (same), or blank
#    (no import baseline / source not found, so no attribution possible).
#
#    Output: a CSV (default inat_import_audit.csv in the repo root) with one
#    row per observation, plus a summary to stdout. No writes to MO or iNat.
#
#    Defaults to a random sample of 10 so a first pass finishes in seconds.
#    Pass --sample 0 (or a large N) to widen; the iNat fetch is batched at
#    200 ids/request with a courtesy pause, so it scales to all imports.
#
#    The work lives in Inat::ImportAudit::{Fetcher,RowBuilder,Runner};
#    this file is just the command-line wrapper.
#
#    See issue #4213 and tracking issue #4208.
#
################################################################################

require_relative("../config/boot")
require_relative("../config/environment")

options = { sample: 10, ids: nil, seed: nil, out: "inat_import_audit.csv" }
args = ARGV.dup
until args.empty?
  case (flag = args.shift)
  when "--sample" then options[:sample] = args.shift.to_i
  when "--ids"    then options[:ids] = args.shift.to_s.split(",")
  when "--seed"   then options[:seed] = args.shift.to_i
  when "--out"    then options[:out] = args.shift
  else warn("Unknown argument: #{flag}")
  end
end

Inat::ImportAudit::Runner.new(**options).run
