# frozen_string_literal: true

#
#  = Occurrence Model
#
#  An Occurrence groups Observations of the same physical mushroom specimen.
#  Typically created when multiple people independently observe the same
#  specimen at large mushroom events.
#
#  == Attributes
#
#  id::                       unique numerical id
#  user_id::                  creator of the Occurrence
#  primary_observation_id::   FK to the default Observation
#  has_specimen::             cached: true if any observation has specimen
#  created_at::               timestamp
#  updated_at::               timestamp
#
class Occurrence < AbstractModel
  include Occurrence::ProjectGaps
  include Occurrence::Logging

  MAX_OBSERVATIONS = 10

  belongs_to :user
  belongs_to :primary_observation, class_name: "Observation"
  belongs_to :field_slip, optional: true
  has_many :observations, dependent: :nullify

  validates :field_slip_id, uniqueness: true, allow_nil: true

  scope :observations, lambda { |obs|
    obs_ids = obs.is_a?(Array) ? obs.map(&:to_i) : [obs.to_i]
    joins(:observations).where(observations: { id: obs_ids }).distinct
  }
  scope :field_slips, lambda { |slips|
    slip_ids = slips.is_a?(Array) ? slips.map(&:to_i) : [slips.to_i]
    where(field_slip_id: slip_ids)
  }

  # Any logged-in user can edit an occurrence.
  def can_edit?(_user)
    true
  end

  validates :primary_observation, presence: true
  validate :primary_observation_must_belong_to_occurrence, on: :update
  validate :observation_count_within_limits, on: :update

  # Recompute cached has_specimen from associated observations.
  def recompute_has_specimen!
    update!(has_specimen: observations.where(specimen: true).exists?)
  end

  # Nightly safety net: recompute has_specimen on all occurrences.
  def self.refresh_has_specimen_cache(dry_run: false)
    msgs = []
    find_each do |occ|
      correct = occ.observations.where(specimen: true).exists?
      next if occ.has_specimen == correct

      msgs << "Occurrence ##{occ.id}: has_specimen " \
              "#{occ.has_specimen} -> #{correct}"
      occ.update!(has_specimen: correct) unless dry_run
    end
    msgs
  end

  # Recalculate shared consensus across all observations.
  def recalculate_consensus!
    obs = observations.naming_includes.first
    return unless obs

    Observation::NamingConsensus.new(obs).calc_consensus
  end

  # Auto-destroy if reduced to fewer than 2 observations,
  # unless linked to a field slip (which needs the occurrence).
  def destroy_if_incomplete!
    return unless observations.count < 2
    return if field_slip_id.present?

    reset_cross_observation_thumbnails
    destroy!
  end

  # Dissolve the occurrence: detach all non-primary observations.
  # If a field slip is linked, keep the occurrence with just the
  # primary. Otherwise destroy it entirely.
  def dissolve!
    non_primary = observations.where.not(id: primary_observation_id).to_a
    reset_cross_observation_thumbnails
    dissolve_transaction(non_primary)
    dissolve_log_and_recalculate(non_primary)
  end

  # Reset any thumbnail that points to an image belonging to a
  # different observation.  Called before destroying or dissolving.
  def reset_cross_observation_thumbnails
    observations.includes(:images).find_each do |obs|
      next if obs.thumb_image_id.nil?
      next if obs.image_ids.include?(obs.thumb_image_id)

      new_thumb = obs.images.order(:id).first
      obs.update!(thumb_image: new_thumb)
    end
  end

  # When an observation is removed from an occurrence, any sibling
  # whose thumbnail came from the departing observation needs a new one.
  def reassign_thumbnails_from(departing_obs)
    departing_image_ids = departing_obs.image_ids
    return if departing_image_ids.empty?

    observations.where.not(id: departing_obs.id).
      where(thumb_image_id: departing_image_ids).find_each do |obs|
        new_thumb = obs.images.order(:id).first
        obs.update!(thumb_image: new_thumb)
      end
  end

  # Create an occurrence manually from a set of observations.
  # The caller picks the default; selected_obs must include it.
  def self.create_manual(primary_obs, selected_obs, user)
    check_field_slip_conflicts!(selected_obs)
    check_max_observations!(selected_obs)

    occurrences = selected_obs.filter_map(&:occurrence).uniq
    if occurrences.any?
      merge_into_manual(occurrences, primary_obs, selected_obs, user)
    else
      build_new(primary_obs, selected_obs, user)
    end
  end

  # Reject if observations belong to more than one existing occurrence.
  def self.check_multiple_occurrences!(occurrences)
    return if occurrences.size <= 1

    occ = new
    occ.errors.add(
      :base,
      "Cannot combine observations from multiple existing " \
      "occurrences (IDs: #{occurrences.map(&:id).join(", ")})"
    )
    raise(ActiveRecord::RecordInvalid.new(occ))
  end

  # Merge +absorbed+ occurrence into +keeper+. All observations from
  # +absorbed+ move to +keeper+, then +absorbed+ is destroyed.
  def self.merge!(keeper, absorbed)
    merged_obs = absorbed.observations.to_a
    transaction do
      merged_obs.each do |obs|
        obs.update!(occurrence: keeper)
      end
      absorbed.reload.destroy!
      keeper.recompute_has_specimen!
    end
    log_observation_added(merged_obs)
    keeper
  end

  # Check that no two observations belong to different field slips.
  def self.check_field_slip_conflicts!(obs_list)
    codes = obs_list.filter_map { |o| o.field_slip&.code }.uniq
    return if codes.size <= 1

    occ = new
    occ.errors.add(
      :base,
      :occurrence_field_slip_conflict.t(codes: codes.join(", "))
    )
    raise(ActiveRecord::RecordInvalid.new(occ))
  end

  # Raise if total observation count would exceed MAX_OBSERVATIONS.
  def self.check_max_observations!(obs_list)
    return if obs_list.size <= MAX_OBSERVATIONS

    occ = new
    occ.errors.add(:base, "Cannot exceed #{MAX_OBSERVATIONS} observations")
    raise(ActiveRecord::RecordInvalid.new(occ))
  end

  # Merge existing occurrences and add remaining observations.
  def self.merge_into_manual(occurrences, primary_obs, all_obs, _user)
    keeper = occurrences.shift
    occurrences.each { |occ| merge!(keeper, occ) }
    newly_added = []
    all_obs.each do |obs|
      next if obs.occurrence_id == keeper.id

      obs.update!(occurrence: keeper)
      newly_added << obs
    end
    log_observation_added(newly_added) if newly_added.any?
    keeper.update!(primary_observation: primary_obs)
    keeper.recompute_has_specimen!
    keeper
  end
  private_class_method :merge_into_manual

  # Build and persist a brand-new occurrence with the given
  # observations.
  def self.build_new(primary_obs, all_obs, user)
    transaction do
      occ = create!(user: user, primary_observation: primary_obs)
      all_obs.each { |obs| obs.update!(occurrence: occ) }
      occ.recompute_has_specimen!
      log_observation_added(all_obs, user)
      occ
    end
  end
  private_class_method :build_new

  private

  def primary_observation_must_belong_to_occurrence
    return if primary_observation_id.blank?
    return if primary_observation_belongs?

    errors.add(:primary_observation,
               "must belong to this occurrence")
  end

  def primary_observation_belongs?
    if observations.loaded?
      observations.any? { |o| o.id == primary_observation_id }
    else
      observations.where(id: primary_observation_id).exists?
    end
  end

  def observation_count_within_limits
    return if observations.count <= MAX_OBSERVATIONS

    errors.add(:observations,
               "must have at most #{MAX_OBSERVATIONS} observations")
  end

  def dissolve_transaction(non_primary)
    transaction do
      non_primary.each { |obs| obs.update!(occurrence: nil) }
      if field_slip_id.present?
        reload
      else
        primary_observation.update!(occurrence: nil)
        reload.destroy!
      end
    end
  end

  def dissolve_log_and_recalculate(non_primary)
    detached = non_primary
    detached += [primary_observation] if field_slip_id.blank?
    detached.each do |obs|
      Occurrence.log_observation_removed(obs)
      Observation::NamingConsensus.new(obs).calc_consensus
    end
  end
end
