# frozen_string_literal: true

module Projects
  # "Add my observations to this project" -- matching a member's
  # observations against the project's constraints (location
  # bounding box, date range) and adding the ones not already in the
  # project. Shared by MembersController's add_obs_modal and the
  # change-status form's "Add My Observations" option.
  module AddableObservations
    extend ActiveSupport::Concern

    class_methods do
      # Per-click cap on "Add My Observations". Method (not constant)
      # so tests can stub it via Minitest stub. See issue #4129.
      def add_obs_batch_limit = 100
    end

    private

    def add_observations(project, candidate)
      # Returns the count of observations added. Caps each click at
      # add_obs_batch_limit most-recent matching observations so the
      # request stays synchronous.
      obs = addable_observations(project, candidate).
            order(id: :desc).limit(self.class.add_obs_batch_limit)
      before = project.observations.count
      project.add_observations(obs)
      project.observations.count - before
    end

    # Observations owned by candidate that match project constraints and
    # are not already in project.observations. Date bounds are applied
    # independently so projects with only a start_date or only an
    # end_date still constrain correctly.
    def addable_observations(project, candidate)
      obs = within_project_location(candidate.observations, project)
      obs = within_project_dates(obs, project)
      obs.where.not(id: project.observations.select(:id))
    end

    def within_project_location(obs, project)
      loc = project.location
      return obs unless loc

      obs.in_box(north: loc.north, south: loc.south,
                 east: loc.east, west: loc.west)
    end

    def within_project_dates(obs, project)
      obs = obs.found_after(project.start_date.strftime("%Y-%m-%d")) \
        if project.start_date
      obs = obs.found_before(project.end_date.strftime("%Y-%m-%d")) \
        if project.end_date
      obs
    end
  end
end
