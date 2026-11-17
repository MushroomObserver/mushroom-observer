# frozen_string_literal: true

# Looks up a project's target Names and Locations on iNaturalist and
# saves the answers, so the External Sites page, an import and the alert
# cycle can read them instead of asking iNat while someone waits.
#
# Paced at one lookup a second, iNat's guideline. The inat_lookups
# queue has one worker thread (config/queue.yml), so one project is
# looked up at a time and the pace holds across projects. When iNat
# refuses a lookup, the job runs again later; what it already looked up
# stays saved.
#
# The External Sites page shows its progress live, then the count of
# what an import would bring in once every target is looked up.
class InatTargetLookupJob < ApplicationJob
  queue_as :inat_lookups

  LOOKUP_PACE = 1
  RETRY_WAIT = 1.minute
  PROGRESS_EVERY = 5

  # A run can outlast Solid Queue's default three-minute hold. A job
  # queued while one is running for the project is discarded: the
  # running one checks for new targets before it finishes.
  limits_concurrency(to: 1, key: ->(project) { "inat_lookup_#{project.id}" },
                     duration: 1.hour, on_conflict: :discard)

  # Queues the job when something reads the project's lookups.
  def self.look_up_later(project)
    site = project.project_external_sites.
           find_by(external_site: ExternalSite.inaturalist)
    return unless site
    return unless site.alerting? ||
                  (site.use_constraints? && project.constraints?)

    perform_later(project)
  end

  def self.stream(project)
    [project, :inat_target_lookups]
  end

  def perform(project)
    @project = project
    looked_up = false
    until (saved = Inat::ConstraintMapper.new(@project.reload)).complete?
      mapper = look_up(saved.looked_up_count)
      return retry_later if mapper.refused?
      # Nothing was saved, so another pass would ask iNat the same things.
      return if mapper.new_answers.zero?

      looked_up = true
    end
    broadcast_candidates if looked_up
  end

  private

  def look_up(already)
    Inat::ConstraintMapper.new(@project, look_up: true,
                                         pace: LOOKUP_PACE) do |mapper|
      next unless (mapper.new_answers % PROGRESS_EVERY).zero?

      broadcast_progress(already + mapper.new_answers, mapper.target_count)
    end.look_up_targets
  end

  def retry_later
    self.class.set(wait: RETRY_WAIT).perform_later(@project)
  end

  def broadcast_progress(looked_up, total)
    broadcast(
      "inat_target_lookup_progress",
      Views::Controllers::Projects::ExternalSites::LookupProgress.new(
        looked_up: looked_up, total: total
      )
    )
  end

  def broadcast_candidates
    site = inat_site
    broadcast(
      "project_site_candidates",
      Views::Controllers::Projects::ExternalSites::Candidates.new(
        candidates: Inat::CandidateCount.for(project_site: site),
        import_limit: site.import_limit
      )
    )
  end

  # The row the External Sites page shows: the saved one, or the
  # unsaved one it draws on before the first save.
  def inat_site
    site = ExternalSite.inaturalist
    @project.project_external_sites.find_by(external_site: site) ||
      @project.project_external_sites.new(
        external_site: site, use_constraints: @project.constraints?
      )
  end

  def broadcast(target, view)
    Turbo::StreamsChannel.broadcast_replace_to(
      self.class.stream(@project),
      target: target,
      html: ApplicationController.renderer.render(view, layout: false)
    )
  end
end
