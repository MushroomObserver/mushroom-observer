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

    # Collects whatever the block raises, then writes the rows and
    # mails them. Returns whatever the block returns.
    #
    # `mail: false` writes the rows and tells nobody, which is what an
    # import wants: whoever ran it knows what they brought in, and
    # iNaturalist told a watching project there. The rows still have
    # to exist, since a watched name arriving is what a later move off
    # it reads as activity on.
    def self.around(mail: true)
      return yield if current

      Thread.current[KEY] = new
      begin
        result = yield
        mail ? current.deliver : current.record_all
        result
      ensure
        Thread.current[KEY] = nil
      end
    end

    # Outside an action -- a console, a test, a callback MO does not
    # wrap -- there is nobody to flush, so the change raises nothing.
    def self.touch(observation, target, provisional: false)
      return if ProjectAlert.suppressed?

      current&.touch(observation, target, provisional: provisional)
    end

    def initialize
      @touched = {}
      @namings = Hash.new { |hash, key| hash[key] = [] }
      @provisional = {}
    end

    # `provisional` says the name arriving is a code waiting to be
    # confirmed, which only the resync knows: the flag lives on
    # iNaturalist, not on the MO Name.
    def touch(observation, target, provisional: false)
      return unless observation

      @namings[observation.id] << target if target.is_a?(Naming)
      @provisional[observation.id] ||= provisional
      @touched[observation.id] = [observation, better_target(observation,
                                                             target)]
    end

    # The rows this action calls for, written.
    def record_all
      @touched.values.flat_map { |obs, target| record(obs, target) }
    end

    def deliver
      ProjectAlert.deliver_digests(record_all)
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

    # What this project hears about an action on this observation. A
    # watched name arriving is a find the first time and activity after
    # that; a comment is activity on an observation the project already
    # has. Anything else is somebody else's observation.
    def alert_for(project, observation, target)
      return nil if left_out?(project, observation)

      told = ProjectAlert.last_alert_for(project, observation)
      return comment_alert(project, observation, target, told) if
        target.is_a?(Comment)

      name_alert(project, observation, target, told)
    end

    # Excluding an observation is how a project says it reviewed one and
    # left it out, so it hears no more about it. An iNaturalist
    # observation nobody imported has no row to exclude: the way to
    # leave one out is to import it and exclude it here.
    def left_out?(project, observation)
      project.excluded_observations.include?(observation)
    end

    # A watched name arriving, whether on a new observation or proposed
    # on an older one. A name arriving on an observation the project has
    # been told about is activity on it, whatever the name says.
    def name_alert(project, observation, target, told)
      name = watched_name(project, observation)
      return activity(project, observation, target, told.target_name) if
        name.nil? && told
      return nil unless name

      ProjectAlert.record_local(project: project, observation: observation,
                                target: target, target_name: name.text_name,
                                proposal: { name: name.text_name })
    end

    # A comment is no find: an observation becomes the project's business
    # by being added to it or reported to it, not by being talked about.
    def comment_alert(project, observation, target, told)
      return activity(project, observation, target, told.target_name) if told
      return nil unless project.observations.exists?(observation.id)

      activity(project, observation, target,
               watched_name(project, observation)&.text_name.presence ||
               observation.name&.text_name.to_s)
    end

    def activity(project, observation, target, target_name)
      ProjectAlert.record_local(
        project: project, observation: observation, target: target,
        target_name: target_name,
        proposal: { name: observation.name&.text_name.to_s,
                    provisional: @provisional[observation.id] || false }
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
