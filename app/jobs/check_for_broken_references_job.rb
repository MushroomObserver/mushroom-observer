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

  def perform(dry_run: false, verbose: false)
    @dry_run = dry_run
    @verbose = verbose
    @reflections = discover_belongs_to_reflections

    Checks::MONOMORPHIC.each { |args| check_monomorphic(*args) }
    Checks::POLYMORPHIC.each { |args| check_polymorphic(*args) }
    report_missing_reflections
  end

  private

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

    apply_action(model, column, query, ids, action)
  end

  # A Checks::MONOMORPHIC/POLYMORPHIC entry naming an association that no
  # longer exists (renamed, removed, or turned polymorphic) is exactly the
  # kind of drift that goes silently unnoticed without this job actually
  # running - alert loudly rather than crash or (worse) fail silently.
  def log_stale_check(key)
    log("STALE CHECK: #{key} is declared in CheckForBrokenReferencesJob::" \
        "Checks, but no such belongs_to association exists anymore. " \
        "Update or remove that entry.")
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

  def apply_action(model, column, query, ids, action)
    case action
    when :alert then alert_broken(model, column, ids)
    when :delete then delete_broken(model, column, query, ids)
    when :nil then nullify_broken(model, column, query, ids)
    when :zero then zero_broken(model, column, query, ids)
    else raise_invalid_action(model, action)
    end
  end

  # Logs a count + bounded sample rather than the full id list - :alert
  # rows should be rare (something's wrong upstream), but an unbounded
  # `ids.inspect` would blow up log/job.log if that assumption is ever
  # wrong (e.g. after a bad data migration).
  def alert_broken(model, column, ids)
    log("ALERT!! #{model.table_name}.#{column}: #{ids.size} bad row(s), " \
        "e.g. #{ids.first(10).inspect}")
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
    query.delete_all unless @dry_run
    log("DELETING #{ids.count} #{model.name.pluralize(ids.count)} " \
        "whose target #{ref_model.name} doesn't exist#{dry_run_note}")
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
      log("MISSING REFLECTION #{key}") if val != :done
    end
  end
end
