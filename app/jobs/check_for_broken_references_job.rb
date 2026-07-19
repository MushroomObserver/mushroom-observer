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
# Cross-checks Checks::MONOMORPHIC/POLYMORPHIC (see check_for_broken_
# references_job/checks.rb) against reality in both directions:
#   - a real `belongs_to` reflection with no entry in either list logs
#     "MISSING REFLECTION" (new association, integrity check never added)
#   - a list entry naming an association that doesn't exist anymore
#     (renamed/removed/turned polymorphic) logs "STALE CHECK" instead of
#     raising - these lists are hand-maintained and drift silently otherwise
class CheckForBrokenReferencesJob < ApplicationJob
  queue_as :maintenance

  # One dangling-reference finding: the referencing model + column, the
  # referenced model, and the offending rows. Bundled so every action can
  # name the referenced model in its report without a long param list.
  Finding = Data.define(:model, :column, :ref_model, :query, :ids)

  def perform(dry_run: false, verbose: false)
    @dry_run = dry_run
    @verbose = verbose
    @review_findings = []
    @reflections = discover_belongs_to_reflections

    Checks::MONOMORPHIC.each { |args| check_monomorphic(*args) }
    Checks::POLYMORPHIC.each { |args| check_polymorphic(*args) }
    report_missing_reflections
    emit_review_summary
  end

  private

  # Everything routed here (dangling :alert references, stale checks,
  # missing reflections) is "a human should look at this" - collected
  # across the run and delivered as a single #alerts summary. Routine
  # :delete/:nil/:zero cleanups stay in job.log only.
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

  def discover_belongs_to_reflections
    reflections = {}
    Dir.foreach(Rails.root.join("app/models")) do |path|
      next unless path.match?(/^\w+\.rb$/)

      model = model_from_file(path)
      next unless model

      poly_fks = polymorphic_foreign_keys(model)
      model.reflect_on_all_associations(:belongs_to).each do |reflection|
        next if typed_polymorphic_view?(reflection, poly_fks)

        reflections["#{model.name}.#{reflection.name}"] = :need
      end
    end
    reflections
  end

  def polymorphic_foreign_keys(model)
    model.reflect_on_all_associations(:belongs_to).
      select(&:polymorphic?).map(&:foreign_key)
  end

  # A scoped belongs_to that reuses a polymorphic association's foreign key -
  # e.g. Comment#location, defined on `target_id` to allow typed joins - is
  # just a typed view of the `target` association, already validated by the
  # polymorphic check. Don't flag it as a separately-uncovered reflection.
  def typed_polymorphic_view?(reflection, poly_fks)
    !reflection.polymorphic? && poly_fks.include?(reflection.foreign_key)
  end

  def model_from_file(path)
    model = path.sub(/\.rb$/, "").classify.constantize
    model if model < ActiveRecord::Base
  rescue NameError
    nil
  end

  def check_monomorphic(model, reflection_name, action)
    reflection = monomorphic_reflection(model, reflection_name)
    if reflection.nil?
      log_stale_check("#{model.name}.#{reflection_name}")
      return
    end

    column = reflection.foreign_key
    ref_model = reflection.class_name.constantize
    mark_checked("#{model.name}.#{reflection_name}", model.name,
                 reflection_name)
    query = broken_relation(model, column, ref_model)
    ids = query.pluck(:id)
    return if ids.empty?

    apply_action(
      Finding.new(model: model, column: column, ref_model: ref_model,
                  query: query, ids: ids),
      action
    )
  end

  # A Checks::MONOMORPHIC/POLYMORPHIC entry naming an association that no
  # longer exists (renamed, removed, or turned polymorphic) is exactly the
  # kind of drift that goes silently unnoticed without this job actually
  # running - alert loudly rather than crash or (worse) fail silently.
  def log_stale_check(key)
    log("STALE CHECK: #{key} is declared in CheckForBrokenReferencesJob::" \
        "Checks, but no such belongs_to association exists anymore. " \
        "Update or remove that entry.")
    note_for_review("STALE CHECK: #{key} (declared, but no such belongs_to)")
  end

  # `model` may be a `::Version` class (e.g. `Name::Version`), which
  # doesn't declare its own `belongs_to` reflections - it shares the
  # base model's (e.g. `Name`'s).
  def monomorphic_reflection(model, reflection_name)
    model2 = model.name.sub("::Version", "").constantize
    model2.reflections[reflection_name.to_s] ||
      model.reflections[reflection_name.to_s]
  end

  def broken_relation(model, column, ref_model)
    model.where(column => 1..).where.not(column => ref_model.all)
  end

  def mark_checked(key, *verbose_args)
    log("#{verbose_args.join(" ")}...") if @verbose
    @reflections[key] = :done
  end

  # Every action -- the mutating :delete/:nil/:zero cleanups as well as
  # :alert -- reports to the #alerts summary, so a dangling reference is
  # always visible: a cleanup you didn't expect is itself the signal that
  # some deletion path isn't cleaning up at its source. The sample is
  # captured up front, before the mutation removes/changes those rows.
  def apply_action(finding, action)
    pairs = broken_pairs(finding)
    case action
    when :alert then alert_broken(finding, pairs)
    when :delete then delete_broken(finding, pairs)
    when :nil then nullify_broken(finding, pairs)
    when :zero then zero_broken(finding, pairs)
    else raise_invalid_action(finding.model, action)
    end
  end

  # A bounded sample, each row rendered as "<Model> <id> -> missing
  # <RefModel> <fk>" so the message reads as a sentence and can't be
  # misread as a list of FK values. Bounded because an unbounded pluck
  # would blow up log/job.log after e.g. a bad data migration.
  def broken_pairs(finding)
    finding.query.limit(10).pluck(:id, finding.column).map do |id, fk|
      "#{finding.model.name} #{id} -> missing #{finding.ref_model.name} #{fk}"
    end
  end

  def alert_broken(finding, pairs)
    summary = "#{finding.ids.size} #{finding.model.name} rows point to a " \
              "#{finding.ref_model.name} that no longer exists " \
              "(via #{finding.column})"
    log("ALERT!! #{summary}: #{pairs.first(10).join("; ")}")
    review_note(pairs, summary)
  end

  def delete_broken(finding, pairs)
    finding.query.delete_all unless @dry_run
    report_cleanup(finding, pairs, "Deleted")
  end

  def nullify_broken(finding, pairs)
    finding.query.update_all(finding.column => nil) unless @dry_run
    report_cleanup(finding, pairs, "Nulled")
  end

  def zero_broken(finding, pairs)
    finding.query.update_all(finding.column => 0) unless @dry_run
    report_cleanup(finding, pairs, "Zeroed")
  end

  # Log + #alerts summary for a mutating cleanup (:delete/:nil/:zero).
  def report_cleanup(finding, pairs, verb)
    summary = "#{verb} #{finding.ids.size} #{finding.model.name} rows " \
              "referencing a missing #{finding.ref_model.name} " \
              "(via #{finding.column})#{dry_run_note}"
    log(summary)
    review_note(pairs, summary)
  end

  def review_note(pairs, summary)
    note_for_review("#{summary} -- e.g. #{pairs.first(3).join("; ")}")
  end

  # Appended to mutation log lines so a dry run doesn't read as if it
  # actually deleted/nulled/zeroed anything.
  def dry_run_note
    @dry_run ? " (dry run)" : ""
  end

  def raise_invalid_action(model, action)
    raise("OOPS! action for #{model.name}, #{action.inspect}, is invalid!")
  end

  def check_polymorphic(model, ref_model)
    unless polymorphic_target?(model)
      log_stale_check("#{model.name}.target")
      return
    end

    mark_checked("#{model.name}.target", model.name, "target",
                 ref_model.name)
    query = polymorphic_relation(model, ref_model)
    ids = query.pluck(:id)
    return if ids.empty?

    delete_broken_polymorphic(model, ref_model, query, ids)
  end

  def delete_broken_polymorphic(model, ref_model, query, ids)
    finding = Finding.new(model: model, column: :target_id,
                          ref_model: ref_model, query: query, ids: ids)
    pairs = broken_pairs(finding)
    query.delete_all unless @dry_run
    summary = "Deleted #{ids.size} #{model.name} rows whose target " \
              "#{ref_model.name} no longer exists#{dry_run_note}"
    log(summary)
    review_note(pairs, summary)
  end

  def polymorphic_target?(model)
    reflection = model.reflect_on_association(:target)
    reflection.present? && reflection.polymorphic?
  end

  def polymorphic_relation(model, ref_model)
    model.where(target_type: ref_model.name, target_id: 1..).
      where.not(target_id: ref_model.all)
  end

  def report_missing_reflections
    @reflections.each do |key, val|
      next if val == :done

      log("MISSING REFLECTION #{key}")
      note_for_review("MISSING REFLECTION: #{key}")
    end
  end
end
