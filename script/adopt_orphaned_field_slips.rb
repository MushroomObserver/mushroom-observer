#!/usr/bin/env ruby
# frozen_string_literal: true

# Associate previously-orphaned field slips (project_id nil) with the
# project whose field_slip_prefix matches their code — but only when the
# slip's owner is already a member of that project. Run once to clean up
# slips created before their project's prefix was set (e.g. FS 3930 in
# issue #4436), where the on-prefix-change hook never fired.
#
#   bin/rails runner script/adopt_orphaned_field_slips.rb
#
# Idempotent and safe to re-run: it reuses Project#adopt_matching_field_slips,
# which skips non-member-owned slips, so it never grants a project's admins
# edit rights over a non-member's field slips. See app/models/project.rb.

class OrphanedFieldSlipAdopter
  def run
    prefixed_projects = Project.where.not(field_slip_prefix: [nil, ""])
    puts("Scanning #{prefixed_projects.count} projects with a prefix...")

    total = 0
    prefixed_projects.find_each do |project|
      adopted = project.adopt_matching_field_slips
      next if adopted.empty?

      total += adopted.size
      adopted.each do |slip|
        puts("  FS #{slip.id} (#{slip.code}) -> project #{project.id} " \
             "(#{project.title})")
      end
    end

    puts("Done. Adopted #{total} orphaned field slips.")
  end
end

OrphanedFieldSlipAdopter.new.run
