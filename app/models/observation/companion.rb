# frozen_string_literal: true

# The editable twin of a read-only reflection (#4214). A reflection's
# snapshot (date, location, GPS, notes, images) mirrors its source and
# cannot be edited on MO, so Edit hands the user a companion
# observation in the same occurrence: one that already exists, or a
# new one copying the snapshot. The native companion is the
# occurrence's primary (a reflection is not), and -- members of an
# occurrence share project membership -- it joins the reflection's
# projects. Images stay on the reflection: the occurrence pools its
# members' images for display, so the companion only points its
# thumbnail at the reflection's.
class Observation::Companion
  # `collector_user_id` is left to the model, which re-derives it from
  # `collector` on save.
  SNAPSHOT = [:when, :where, :location_id, :lat, :lng, :alt, :gps_hidden,
              :is_collection_location, :specimen, :notes,
              :collector].freeze

  def initialize(reflection, user)
    @reflection = reflection
    @user = user
  end

  # A non-reflection member of the occurrence the user may edit, made
  # the primary if a reflection still holds that spot. Read from the
  # database, not the reflection's loaded association, which can
  # predate a companion created moments ago.
  def existing
    return unless @reflection.occurrence_id

    companion = Observation.where(occurrence_id: @reflection.occurrence_id).
                where.not(id: @reflection.id).order(:id).
                find { |obs| !obs.reflection? && obs.can_edit?(@user) }
    make_primary(companion) if companion
    companion
  end

  # Raises ActiveRecord::RecordInvalid when the occurrence is full.
  def create
    Observation.transaction do
      companion = build
      companion.save!
      propose_name(companion)
      join_occurrence(companion)
      point_thumbnail(companion)
      join_projects(companion)
      companion.log(:log_observation_created, user: @user)
      companion
    end
  end

  private

  def build
    attrs = @reflection.attributes.symbolize_keys.slice(*SNAPSHOT)
    obs = Observation.new(attrs.merge(user: @user, name: name,
                                      source: "mo_website"))
    obs.current_user = @user
    obs
  end

  # Fetched afresh: the reflection may come from a strict-loading
  # query, and proposing a name walks the Name's interests.
  def name
    @name ||= Name.find(@reflection.name_id)
  end

  def propose_name(companion)
    naming = companion.namings.create!(name: name, user: @user)
    Observation::NamingConsensus.new(companion).
      change_vote(naming, Vote.maximum_vote, @user)
  end

  def join_occurrence(companion)
    occurrence = @reflection.occurrence
    if occurrence
      Occurrence.check_max_observations!(occurrence.observations.to_a +
                                         [companion])
      companion.update!(occurrence: occurrence)
      Occurrence.log_observation_added([companion], @user)
      occurrence.recompute_has_specimen!
      make_primary(companion)
    else
      Occurrence.create_manual(companion, [@reflection, companion], @user)
    end
  end

  def make_primary(companion)
    occurrence = Occurrence.find(companion.occurrence_id)
    return if occurrence.primary_observation_id == companion.id

    occurrence.update!(primary_observation: companion)
  end

  # Any occurrence member's image may be an observation's thumbnail.
  def point_thumbnail(companion)
    return unless @reflection.thumb_image_id

    companion.update!(thumb_image_id: @reflection.thumb_image_id)
  end

  def join_projects(companion)
    @reflection.projects.each { |project| project.add_observation(companion) }
  end
end
