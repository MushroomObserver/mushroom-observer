# frozen_string_literal: true

class Inat
  # One alerting project's side of the cycle (#5416): the taxa it
  # watches, and whether a candidate observation belongs to it.
  #
  # The preview asks iNat the same question as a search -- taxa AND
  # places AND box AND dates (`Inat::ConstraintMapper`). This asks it
  # of one observation, locally, so the two agree about what belongs.
  # The difference is what the answer is for: a count there, a message
  # here.
  #
  # A project qualifies only with target names and target locations
  # set. Those are what make the poll selective, and they are what a
  # rare challenge has; a foray wants importing, not alerts.
  class AlertCriteria
    def self.all_alerting(site)
      ProjectExternalSite.alerting.where(external_site: site).
        includes(project: [:target_names, :target_locations, :location]).
        map { |row| new(row) }.select(&:qualified?)
    end

    attr_reader :project_site, :project

    def initialize(project_site)
      @project_site = project_site
      @project = project_site.project
    end

    def qualified?
      project.target_names_present? && project.target_locations_present? &&
        taxon_ids.any?
    end

    def taxon_ids
      @taxon_ids ||= Inat::ConstraintMapper.new(project).target_taxon_ids
    end

    # The identification this project would be told about: a current
    # one naming a taxon it watches. The newest wins when there are
    # several, since that is what the observation now says.
    def alertable_identification(candidate)
      candidate.current_identifications.
        select { |ident| taxon_ids.include?(ident[:taxon_id]) }.
        max_by { |ident| ident[:id].to_i }
    end

    def matches?(candidate)
      within_dates?(candidate.observed_on) && within_area?(candidate)
    end

    # Whoever opted in, which is nobody until a site admin names them.
    # Being an admin of a project is not a request to be told what
    # iNaturalist identified overnight.
    def recipients
      project_site.alert_recipients
    end

    private

    def within_dates?(observed_on)
      return true if observed_on.blank?
      return false if project.start_date && observed_on < project.start_date
      return false if project.end_date && observed_on > project.end_date

      true
    end

    # An observation iNat gives no point for still belongs: it withholds
    # the point for an obscured or private observation, and a rare find
    # is the case where an admin most wants to hear. The preview counts
    # it too, for the same reason.
    def within_area?(candidate)
      return true if candidate.lat.nil? || candidate.lng.nil?

      inside_project_box?(candidate) && inside_a_target_location?(candidate)
    end

    def inside_project_box?(candidate)
      box = project.location
      return true if box.nil?

      inside?(box, candidate)
    end

    def inside_a_target_location?(candidate)
      project.target_locations.any? { |loc| inside?(loc, candidate) }
    end

    def inside?(location, candidate)
      location.contains?(candidate.lat, candidate.lng)
    end
  end
end
