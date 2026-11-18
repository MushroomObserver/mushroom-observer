# frozen_string_literal: true

class ProjectAlert
  # One set of digests per completed action (#5721).
  #
  # A person adding an observation, naming it and commenting on it
  # does one thing, so the projects watching for it hear once. Each
  # model callback hands the observation here instead of mailing, and
  # the request's end decides who hears what: ApplicationController
  # wraps every action, the API included.
  #
  # A record created outside a request raises nothing, which is what
  # an import and a resync want. A job that means to alert wraps its
  # perform in `around`.
  #
  # Nested blocks belong to the outer action, so a job that wraps its
  # work and a model that wraps a save do not each flush.
  #
  # An action that raises flushes nothing. The records it was about
  # rolled back with it.
  class Collector
    KEY = :project_alert_collector

    # The record whose arrival is worth naming as the reason, when an
    # action brings several: a comment is what someone wrote, a naming
    # is what they proposed, and the observation is the fallback.
    TARGET_RANK = { "Comment" => 0, "Naming" => 1, "Observation" => 2 }.freeze

    def self.current
      Thread.current[KEY]
    end

    # Collects whatever the block raises, then delivers it. Returns
    # whatever the block returns.
    def self.around
      return yield if current

      Thread.current[KEY] = new
      begin
        result = yield
        current.deliver
        result
      ensure
        Thread.current[KEY] = nil
      end
    end

    # Outside an action -- a console, a test, a callback MO does not
    # wrap -- there is nobody to flush, so the change raises nothing.
    def self.touch(observation, target)
      return if ProjectAlert.suppressed?

      current&.touch(observation, target)
    end

    def initialize
      @touched = {}
      @namings = Hash.new { |hash, key| hash[key] = [] }
    end

    def touch(observation, target)
      return unless observation

      @namings[observation.id] << target if target.is_a?(Naming)
      @touched[observation.id] = [observation, better_target(observation,
                                                             target)]
    end

    def deliver
      rows = @touched.values.flat_map { |obs, target| record(obs, target) }
      ProjectAlert.deliver_digests(rows)
    end

    private

    # Keeps the most particular target an action offers.
    def better_target(observation, target)
      held = @touched[observation.id]&.last
      return target unless held

      [held, target].min_by { |record| TARGET_RANK[record.class.name] || 9 }
    end

    def record(observation, target)
      Project.alerting.includes(:project_target_names,
                                :project_target_locations).filter_map do |pr|
        alert_for(pr, observation, target)
      end
    end

    # A watched name applied here, or a comment on something the
    # project was told about already. Anything else is somebody else's
    # observation.
    def alert_for(project, observation, target)
      name = watched_name(project, observation)
      return follow_up(project, observation, target) unless name

      ProjectAlert.record_local(project: project, observation: observation,
                                target: target, name: name.text_name,
                                target_name: name.text_name)
    end

    # Later activity on an observation this project has been told
    # about, which is worth hearing whatever its name says now. The
    # project may have heard it from a site rather than from here, so
    # the watched name comes from whichever row said so.
    def follow_up(project, observation, target)
      return nil unless target.is_a?(Comment)

      told = ProjectAlert.last_alert_for(project, observation)
      return nil unless told

      ProjectAlert.record_local(
        project: project, observation: observation, target: target,
        name: observation.name&.text_name.to_s,
        target_name: told.target_name
      )
    end

    # The name this project watches that the observation now carries,
    # or that somebody proposed on it in this action.
    def watched_name(project, observation)
      return nil unless project.alert_matches_place?(observation)

      candidate_names(observation).find do |name|
        project.alert_matches_name?(name)
      end
    end

    def candidate_names(observation)
      [observation.name,
       *@namings[observation.id].map(&:name)].compact.uniq
    end
  end
end
