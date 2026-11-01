# frozen_string_literal: true

# rubocop:disable MO/NoLongCommentBlock
# One-time repair for issue #5585: NameDescription/LocationDescription
# rows whose text fields are all blank. Most come from two sources: a
# 2012-07 bulk backfill (user_id 0) that stamped a blank default
# description onto every pre-2012 Name that didn't have one yet, and a
# still-live gap where submitting the "create description" form with
# nothing typed becomes the Name's default description (see
# Names::DescriptionsController#set_default_description_if_public --
# fixed separately, not by this script).
#
# A blank description isn't automatically dead weight -- before
# deleting one, this reports (and --apply only deletes) the ones
# where no human claimed the content:
#   - version == 1 -- never revised since creation. Description's
#     `before_save` callback adds the creator as an EDITOR on every
#     save regardless of content (author only when the save actually
#     wrote something -- see Description#author_worthy?), so "has an
#     editor" doesn't by itself mean anyone wrote anything. A
#     never-revised row's only editor is that creation-time artifact.
#   - no project_id -- not an in-progress Project draft.
#   - no authors -- nobody is listed as having written real content.
#
# Everything else (revised at least once, tied to a project, or has a
# listed author) is reported but left alone -- it needs a human look,
# not this script's judgment.
#
# Description's own `before_destroy` callback (update_users_and_parent)
# already nils out the parent's `description_id` when the row being
# destroyed is the parent's current default, and already adjusts
# author/editor contribution stats -- `.destroy` alone handles both,
# no extra reassignment step needed here.
#
# Dry run (default -- reports, writes nothing):
#   bin/rails runner script/purge_blank_descriptions.rb
# Apply:
#   bin/rails runner script/purge_blank_descriptions.rb --apply
# rubocop:enable MO/NoLongCommentBlock

APPLY = ARGV.delete("--apply") ? true : false
if ARGV.any?
  warn("Unknown argument(s): #{ARGV.join(", ")}")
  warn("Usage: bin/rails runner script/purge_blank_descriptions.rb " \
       "[--apply]")
  exit(1)
end

# Reports (and, under --apply, deletes) blank NameDescription/
# LocationDescription rows with no claimed authorship.
class BlankDescriptionPurge
  MODELS = [NameDescription, LocationDescription].freeze

  def initialize(apply:)
    @apply = apply
    @counts = Hash.new(0)
  end

  def run
    MODELS.each { |model| process(model) }
    report
  end

  private

  def process(model)
    model.where(blank_conditions(model)).find_each do |desc|
      next if desc.notes?

      handle(desc)
    end
  end

  # All of the model's note fields NULL or empty -- a loose SQL
  # pre-filter; `desc.notes?` (which also catches whitespace-only
  # fields) is the final word on whether a row is a candidate.
  def blank_conditions(model)
    table = model.arel_table
    model.all_note_fields.inject(nil) do |cond, field|
      blank = table[field].eq(nil).or(table[field].eq(""))
      cond ? cond.and(blank) : blank
    end
  end

  def handle(desc)
    @counts[:candidates] += 1
    reasons = exclusion_reasons(desc)
    warn(describe(desc, reasons))
    return if reasons.any?

    @counts[:eligible] += 1
    return unless @apply

    desc.destroy
    @counts[:deleted] += 1
  end

  def exclusion_reasons(desc)
    reasons = []
    reasons << "revised (version #{desc.version})" if desc.version > 1
    reasons << "project #{desc.project_id}" if desc.project_id
    if desc.authors.any?
      reasons << "authors: #{desc.authors.map(&:login).join(", ")}"
    end
    reasons
  end

  def describe(desc, reasons)
    parent = desc.parent
    status = reasons.any? ? reasons.join("; ") : "ELIGIBLE"
    default = parent && parent.description_id == desc.id ? " DEFAULT" : ""
    editors = desc.editors.map(&:login).join(", ")
    "#{desc.class.name} #{desc.id}: #{desc.parent_type} " \
      "#{parent&.id} (#{parent&.text_name})#{default}, " \
      "editors: [#{editors}] -- #{status}"
  end

  def report
    warn(@counts.map { |key, count| "#{key}: #{count}" }.join(", "))
    return if @apply

    warn("Dry run - nothing written. To apply: " \
         "bin/rails runner script/purge_blank_descriptions.rb --apply")
  end
end

BlankDescriptionPurge.new(apply: APPLY).run
