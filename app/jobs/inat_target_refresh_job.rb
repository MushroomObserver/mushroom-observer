# frozen_string_literal: true

# Re-asks iNaturalist about saved target lookups, longest unconfirmed
# first.
#
# A saved lookup can be wrong while looking fine. iNaturalist commits a
# taxon swap, the id MO holds is deactivated, and the alert poll goes on
# asking for a taxon nothing is identified as any more: the project
# stops hearing about its rare species and nothing says so. Asking the
# taxon itself is what catches that, since the search that found the id
# returns the deactivated taxon under its former name.
#
# A target whose id has moved gets the replacement's name added to every
# project targeting it, beside the name already there, and the poll's
# window reopened back to when the row was last confirmed.
#
# Paced at one lookup a second on the inat_lookups queue, which has one
# worker thread (config/queue.yml), so the pace holds and this stays off
# the threads the alert cycle needs.
class InatTargetRefreshJob < ApplicationJob
  queue_as :inat_lookups

  STALE_AFTER = 1.day

  # 461 rows across the projects with targets, so this re-confirms them
  # all daily and still bounds a run: ten minutes at one a second.
  ROWS_PER_RUN = 600

  # A run outlasts Solid Queue's default three-minute hold. Discarding a
  # second run costs nothing, since rows keep their place in the
  # staleness order.
  limits_concurrency(to: 1, key: "inat_target_refresh", duration: 1.hour,
                     on_conflict: :discard)

  def perform
    @search = Inat::TargetSearch.new(pace: InatTargetLookupJob::LOOKUP_PACE)
    @confirmed = 0
    @moved = []
    due_rows.each do |row|
      break if @search.refused?

      refresh(row)
    end
    report
  end

  private

  def due_rows
    InatTargetLookup.by_staleness.
      where(checked_at: ..STALE_AFTER.ago).limit(ROWS_PER_RUN)
  end

  # A row whose MO record is gone answers a question about nothing.
  def refresh(row)
    target = row.target
    return row.destroy! unless target
    return save(row, target, @search.answer_for(target)) if
      target.is_a?(::Location)

    refresh_taxon(row, target)
  end

  # A miss is re-asked by name, since iNat may have added the name
  # since. A saved answer has no expiry, so without this a miss would
  # stand for good.
  def refresh_taxon(row, name)
    return resolve_miss(row, name) unless row.inat_id

    confirmation = @search.confirm_taxon(row.inat_id)
    return unless confirmation
    return touch(row) if confirmation.active

    follow(row, name, confirmation)
  end

  def resolve_miss(row, name)
    since = row.checked_at
    answer = @search.answer_for(name)
    save(row, name, answer)
    back_scan(answer, since) if answer
  end

  # iNat deactivated the taxon. A single replacement is followed; a
  # split leaves several outputs and no answer to adopt, so the lookup
  # becomes a miss and the next run asks by name.
  def follow(row, name, confirmation)
    replacement = confirmation.replacement_id
    return save(row, name, false) unless replacement

    since = row.checked_at
    adopt(name, replacement)
    @moved << "#{name.text_name} (#{row.inat_id} -> #{replacement})"
    save(row, name, replacement)
    back_scan(replacement, since)
  end

  # The replacement's name joins every project that targets the old one.
  # The old target stays: `Project#remove_target_name` would pull the
  # project's matching observations out with it, and it is the spelling a
  # coordinator entered.
  def adopt(old_name, replacement_id)
    mo_name = mo_name_for(@search.taxon(replacement_id))
    return alert_no_adoption(old_name, replacement_id) unless mo_name

    projects_targeting(old_name).each do |project|
      project.add_target_name(mo_name)
    end
  end

  def mo_name_for(taxon)
    return nil unless taxon

    params = Inat::Taxon.new(taxon.deep_symbolize_keys).mo_name_params
    return nil if params[:name].blank?

    Name.create_with_trusted_rank(User.admin, params[:name], params[:rank])
  end

  def projects_targeting(name)
    Project.joins(:project_target_names).
      where(project_target_names: { name_id: name.id })
  end

  # Re-reading observations costs nothing: the alert ledger's unique
  # index on the identification decides what a project has been told.
  def back_scan(inat_id, since)
    scanner = Inat::AlertScanner.new(since: since, taxon_ids: [inat_id])
    ProjectAlert.deliver_scanned(scanner.scan)
    scanner.warnings.each { |message| alert(message) }
  end

  def save(_row, target, answer)
    return if answer.nil?

    @confirmed += 1
    InatTargetLookup.record(
      target, answer, version: Inat::TargetSearch.matching_version(target)
    )
  end

  # Still current, so only the confirmation time moves.
  # `target_updated_at` stays put: it records which version of the MO
  # record the answer was found for.
  def touch(row)
    @confirmed += 1
    row.update!(checked_at: Time.zone.now)
  end

  def alert_no_adoption(old_name, replacement_id)
    alert("iNaturalist moved #{old_name.text_name.inspect} to taxon " \
          "#{replacement_id}, which has no MO Name and could not be " \
          "created. The id is saved; the name was not added as a target.")
  end

  def report
    log("InatTargetRefreshJob: #{@confirmed} lookup(s) re-confirmed, " \
        "#{@moved.size} moved")
    return if @moved.empty?

    alert("iNaturalist moved #{@moved.size} target taxon id(s), and the " \
          "replacement name(s) joined the projects targeting them: " \
          "#{@moved.join("; ")}")
  end
end
