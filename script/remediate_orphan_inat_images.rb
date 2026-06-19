# frozen_string_literal: true

# One-time remediation of orphaned iNat-imported images (issue #4543).
#
# The #4213 audit found imported images whose iNat source photo was later
# deleted on iNat. Each row of the reviewed CSV (inat_orphan_reviewed.csv)
# carries a human decision in column 2:
#
#   Adopt  -> keep as MO-native. An adopted orphan has no live iNat photo
#             (that is why it is adopted), so its stored provenance is stale:
#             clear source_id + external_id (the combo a future sync keys
#             off, #4215/#4529) AND rewrite the notes prefix from
#             "Imported from iNat ..." to "Adopted from iNat ..." (timestamp
#             preserved). original_name is left untouched.
#   Delete -> the photo was deliberately removed on iNat: destroy the image
#             (same path as the images controller: log_destroy + destroy, so
#             thumbnails are reassigned and join rows cleaned up).
#   Ask    -> awaiting the observer; skipped (no action).
#
# Driven entirely by the CSV, so the production run uses the finalized file.
#
#   bin/rails runner script/remediate_orphan_inat_images.rb          # dry run
#   APPLY=1 bin/rails runner script/remediate_orphan_inat_images.rb  # writes
#   CSV=other.csv APPLY=1 bin/rails runner script/...   # drive a custom CSV
#
# Idempotent: re-running adopts only still-"Imported" notes and deletes only
# images that still exist; everything else is reported and skipped.

require "csv"

IMPORTED_PREFIX = "Imported from iNat"
ADOPTED_PREFIX  = "Adopted from iNat"
DECISIONS = { "adopt" => :adopt, "delete" => :delete }.freeze

def image_ids(cell)
  cell.to_s.split(/\s+/).map(&:to_i).reject(&:zero?)
end

def adopt_changes(img, notes)
  changes = {}
  if notes.start_with?(IMPORTED_PREFIX)
    changes[:notes] = notes.sub(IMPORTED_PREFIX, ADOPTED_PREFIX)
  end
  if img.source_id ||
     img.external_id
    changes[:source_id] = nil
    changes[:external_id] = nil
  end
  changes
end

def adopt_image(img, apply, stats)
  notes = img.notes.to_s
  unless notes.start_with?(IMPORTED_PREFIX, ADOPTED_PREFIX)
    return skip_unexpected(img, notes, stats)
  end

  changes = adopt_changes(img, notes)
  return stats[:already] += 1 if changes.empty?

  img.update_columns(changes) if apply
  cleared = changes.key?(:source_id) ? " +cleared source/external" : ""
  puts("  image #{img.id}: #{apply ? "ADOPTED" : "would adopt"}#{cleared}")
  stats[:adopted] += 1
  stats[:combo_cleared] += 1 if changes.key?(:source_id)
end

def skip_unexpected(img, notes, stats)
  puts("  image #{img.id}: SKIP unexpected notes #{notes[0, 40].inspect}")
  stats[:unexpected] += 1
end

def delete_image(img, apply, stats)
  if apply
    img.log_destroy
    img.destroy
  end
  puts("  image #{img.id}: #{apply ? "DELETED" : "would delete"}")
  stats[:deleted] += 1
end

def act_on_image(id, decision, apply, stats)
  img = Image.find_by(id: id)
  if img.nil?
    note = decision == :delete ? "already deleted" : "cannot adopt"
    puts("  image #{id}: MISSING (#{note})")
    return stats[:missing] += 1
  end

  if decision == :delete
    delete_image(img, apply,
                 stats)
  else
    adopt_image(img, apply, stats)
  end
end

def skip_row(row, ids, stats)
  puts("obs #{row[3]}: SKIP decision=#{row[1].inspect} (#{ids.size} imgs)")
  stats[:skipped_rows] += 1
end

def process_row(row, apply, stats)
  decision = DECISIONS[row[1].to_s.strip.downcase]
  ids      = image_ids(row[12])
  return skip_row(row, ids, stats) if decision.nil?

  puts("obs #{row[3]}: #{decision} (#{ids.size} imgs)")
  ids.each { |id| act_on_image(id, decision, apply, stats) }
end

csv_path = Rails.root.join(ENV["CSV"].presence || "inat_orphan_reviewed.csv")
apply    = ENV["APPLY"] == "1"
abort("CSV not found: #{csv_path}") unless File.exist?(csv_path)

stats = Hash.new(0)
CSV.read(csv_path).drop(1).each { |row| process_row(row, apply, stats) }

puts
puts "== summary =="
puts "  adopted#{" (would)" unless apply}: #{stats[:adopted]}"
puts "    of which source/external cleared: #{stats[:combo_cleared]}"
puts "  deleted#{" (would)" unless apply}: #{stats[:deleted]}"
puts "  already adopted:   #{stats[:already]}"
puts "  missing images:    #{stats[:missing]}"
puts "  unexpected notes:  #{stats[:unexpected]}"
puts "  skipped rows (Ask/blank/unknown): #{stats[:skipped_rows]}"
puts
puts(apply ? "APPLIED." : "Dry run. Re-run with APPLY=1 to write.")
