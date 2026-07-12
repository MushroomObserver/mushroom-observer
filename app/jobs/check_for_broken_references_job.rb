# frozen_string_literal: true

# Finds and fixes dangling `belongs_to` foreign keys (and polymorphic
# `target` references) across the whole schema - rows whose referenced
# record no longer exists. `action` says what to do about it:
#
#   :alert  - just report it (something's wrong upstream; don't guess)
#   :delete - the referencing row is meaningless without its target
#   :nil    - null out the FK (row is still meaningful without it)
#   :zero   - same, but the column isn't nullable (uses 0 as "none")
#
# The (model, association) pairs to check come from live reflection
# introspection (see check_for_broken_references_job/checks.rb), not a
# hand-maintained list - so a renamed, removed, or newly-polymorphic
# association can't silently drift out of what's checked. Two things can
# still need a human's attention, both surfaced as review-worthy log lines
# rather than silently skipped or raised:
#   - a Checks::ACTIONS entry naming an association that doesn't exist
#     anymore logs "STALE ACTIONS ENTRY" (renamed/removed/turned
#     polymorphic - remove the entry)
#   - a real association with no Checks::ACTIONS entry logs
#     "NEEDS ACTION ENTRY" - it's still checked, using the safe
#     Checks::DEFAULT_ACTION, but a human should categorize it properly
class CheckForBrokenReferencesJob < ApplicationJob
  queue_as :maintenance

  def perform(dry_run: false, verbose: false)
    @dry_run = dry_run
    @verbose = verbose
    @review_findings = []

    Checks.monomorphic_associations.each do |model, reflection_name|
      check_monomorphic(model, reflection_name)
    end
    Checks.polymorphic_associations.each do |model, reflection_name|
      Checks.polymorphic_targets(model, reflection_name).each do |ref_model|
        check_polymorphic(model, reflection_name, ref_model)
      end
    end
    report_stale_action_entries
    emit_review_summary
  end

  private

  # Everything routed here (dangling :alert references, stale ACTIONS
  # entries, new associations needing a considered entry) is "a human
  # should look at this" - collected across the run and delivered as a
  # single #alerts summary. Routine :delete/:nil/:zero cleanups stay in
  # job.log only.
  def note_for_review(line)
    (@review_findings ||= []) << line
  end

  # At most one alert per run, and none when the run is clean - so a
  # quiet week is silent rather than a stream of "found 0 problems".
  def emit_review_summary
    return if @review_findings.empty?

    count = @review_findings.size
    alert("found #{count} reference issue(s) needing review:\n- " \
          "#{@review_findings.join("\n- ")}")
  end

  def report_stale_action_entries
    Checks.stale_action_entries.each do |key|
      log("STALE ACTIONS ENTRY: #{key} is declared in " \
          "CheckForBrokenReferencesJob::Checks::ACTIONS, but no such " \
          "belongs_to association exists anymore. Remove that entry.")
      note_for_review("STALE ACTIONS ENTRY: #{key} (declared, but no " \
                      "such belongs_to)")
    end
  end

  def check_monomorphic(model, reflection_name)
    reflection = monomorphic_reflection(model, reflection_name)
    column = reflection.foreign_key
    ref_model = reflection.class_name.constantize
    action = Checks.action_for(model, reflection_name)
    note_new_action_needed(model, reflection_name) unless
      Checks.action_defined?(model, reflection_name)
    log("#{model.name} #{reflection_name}...") if @verbose

    query = broken_relation(model, column, ref_model)
    ids = query.pluck(:id)
    return if ids.empty?

    apply_action(model, column, query, ids, action)
  end

  # A brand-new association with no considered ACTIONS entry yet is still
  # checked (using the safe Checks::DEFAULT_ACTION), but flagged so a
  # human notices and categorizes it - the "self-heals on coverage, not
  # on judgment" half of this job's design (see Checks's file header).
  def note_new_action_needed(model, reflection_name)
    key = "#{model.name}.#{reflection_name}"
    log("NEEDS ACTION ENTRY: #{key} has no entry in Checks::ACTIONS - " \
        "checked with the default (#{Checks::DEFAULT_ACTION}) for now. " \
        "Add a considered entry.")
    note_for_review("NEEDS ACTION ENTRY: #{key} (using default " \
                    "#{Checks::DEFAULT_ACTION})")
  end

  # `model` may be a `::Version` class (e.g. `Name::Version`), which
  # doesn't declare its own `belongs_to` reflection for every association
  # it's checked on - it may share the base model's (e.g. `Name`'s).
  def monomorphic_reflection(model, reflection_name)
    model.reflections[reflection_name.to_s] ||
      model.name.sub("::Version", "").constantize.
        reflections[reflection_name.to_s]
  end

  def broken_relation(model, column, ref_model)
    model.where(column => 1..).where.not(column => ref_model.all)
  end

  def apply_action(model, column, query, ids, action)
    case action
    when :alert then alert_broken(model, column, query, ids)
    when :delete then delete_broken(model, column, query, ids)
    when :nil then nullify_broken(model, column, query, ids)
    when :zero then zero_broken(model, column, query, ids)
    else raise_invalid_action(model, action)
    end
  end

  # Logs a count + a bounded [id, column] sample rather than the full list.
  # Each pair is an offending row's primary key and its dangling #{column}
  # value, so the sample can't be misread as a list of FK values. :alert
  # rows should be rare (something's wrong upstream), but an unbounded pluck
  # would blow up log/job.log if that ever stops holding (e.g. after a bad
  # data migration).
  def alert_broken(model, column, query, ids)
    sample = query.limit(10).pluck(:id, column)
    log("ALERT!! #{ids.size} #{model.table_name} row(s) with a dangling " \
        "#{column} - [id, #{column}]: #{sample.inspect}")
    note_for_review("#{ids.size} #{model.table_name}.#{column} dangling " \
                    "(e.g. #{sample.first(3).inspect})")
  end

  def delete_broken(model, column, query, ids)
    query.delete_all unless @dry_run
    log("DELETING #{ids.count} #{model.name.pluralize(ids.count)} " \
        "whose #{column} doesn't exist#{dry_run_note}")
  end

  def nullify_broken(model, column, query, ids)
    query.update_all(column => nil) unless @dry_run
    log("SETTING #{ids.count} nonexistent #{model.table_name}.#{column} " \
        "TO NIL#{dry_run_note}")
  end

  def zero_broken(model, column, query, ids)
    query.update_all(column => 0) unless @dry_run
    log("SETTING #{ids.count} nonexistent #{model.table_name}.#{column} " \
        "TO ZERO#{dry_run_note}")
  end

  # Appended to mutation log lines so a dry run doesn't read as if it
  # actually deleted/nulled/zeroed anything.
  def dry_run_note
    @dry_run ? " (dry run)" : ""
  end

  def raise_invalid_action(model, action)
    raise("OOPS! action for #{model.name}, #{action.inspect}, is invalid!")
  end

  def check_polymorphic(model, reflection_name, ref_model)
    query = polymorphic_relation(model, reflection_name, ref_model)
    ids = query.pluck(:id)
    return if ids.empty?

    delete_broken_polymorphic(model, ref_model, query, ids)
  end

  def delete_broken_polymorphic(model, ref_model, query, ids)
    query.delete_all unless @dry_run
    log("DELETING #{ids.count} #{model.name.pluralize(ids.count)} " \
        "whose target #{ref_model.name} doesn't exist#{dry_run_note}")
  end

  def polymorphic_relation(model, reflection_name, ref_model)
    type_column = "#{reflection_name}_type"
    id_column = "#{reflection_name}_id"
    model.where(type_column => ref_model.name, id_column => 1..).
      where.not(id_column => ref_model.all)
  end
end
