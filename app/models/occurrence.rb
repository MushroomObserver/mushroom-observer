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
  MAX_OBSERVATIONS = 10

  belongs_to :user
  belongs_to :primary_observation, class_name: "Observation"
  has_many :observations, dependent: :nullify

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

  # Recalculate shared consensus across all observations.
  def recalculate_consensus!
    obs = observations.naming_includes.first
    return unless obs

    Observation::NamingConsensus.new(obs).calc_consensus
  end

  # Auto-destroy if reduced to fewer than 2 observations.
  def destroy_if_incomplete!
    return unless observations.count < 2

    reset_cross_observation_thumbnails
    destroy!
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

  # When a new observation is assigned to a field slip that already has
  # other observations, auto-create or extend an occurrence.
  def self.find_or_create_for_field_slip(field_slip, new_obs, user)
    other_obs = field_slip.observations.where.not(id: new_obs.id).to_a
    return if other_obs.empty?

    existing = existing_occurrence_for(other_obs, new_obs)
    if existing
      add_to_existing(existing, new_obs)
    else
      create_from_field_slip(field_slip, new_obs, other_obs, user)
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

  # Merge +absorbed+ occurrence into +keeper+. All observations from
  # +absorbed+ move to +keeper+, then +absorbed+ is destroyed.
  def self.merge!(keeper, absorbed)
    transaction do
      absorbed.observations.each do |obs|
        obs.update!(occurrence: keeper)
      end
      absorbed.reload.destroy!
      keeper.recompute_has_specimen!
    end
    keeper
  end

  # Check that no two observations belong to different field slips.
  def self.check_field_slip_conflicts!(obs_list)
    codes = obs_list.filter_map { |o| o.field_slip&.code }.uniq
    return if codes.size <= 1

    occ = new
    occ.errors.add(:base, "Field slip code conflict: #{codes.join(", ")}")
    raise(ActiveRecord::RecordInvalid.new(occ))
  end

  # Raise if total observation count would exceed MAX_OBSERVATIONS.
  def self.check_max_observations!(obs_list)
    return if obs_list.size <= MAX_OBSERVATIONS

    occ = new
    occ.errors.add(:base, "Cannot exceed #{MAX_OBSERVATIONS} observations")
    raise(ActiveRecord::RecordInvalid.new(occ))
  end

  # -------------------------------------------------------------------
  #  Private class methods
  # -------------------------------------------------------------------

  # Find the existing occurrence (if any) among the other observations
  # on the field slip or on the new observation itself.
  def self.existing_occurrence_for(other_obs, new_obs)
    occs = (other_obs + [new_obs]).filter_map(&:occurrence).uniq
    occs.first
  end
  private_class_method :existing_occurrence_for

  # Add an observation to an existing occurrence, merging if necessary.
  def self.add_to_existing(occurrence, new_obs)
    if new_obs.occurrence && new_obs.occurrence != occurrence
      merge!(occurrence, new_obs.occurrence)
    elsif new_obs.occurrence_id != occurrence.id
      transaction do
        new_obs.update!(occurrence: occurrence)
        occurrence.recompute_has_specimen!
      end
    end
    occurrence
  end
  private_class_method :add_to_existing

  # Create a new occurrence from all observations on a field slip.
  def self.create_from_field_slip(_field_slip, new_obs, other_obs, user)
    all_obs = (other_obs + [new_obs]).uniq
    check_field_slip_conflicts!(all_obs)
    check_max_observations!(all_obs)
    default = all_obs.min_by(&:created_at)
    build_new(default, all_obs, user)
  end
  private_class_method :create_from_field_slip

  # Merge existing occurrences and add remaining observations.
  def self.merge_into_manual(occurrences, primary_obs, all_obs, _user)
    keeper = occurrences.shift
    occurrences.each { |occ| merge!(keeper, occ) }
    all_obs.each do |obs|
      next if obs.occurrence_id == keeper.id

      obs.update!(occurrence: keeper)
    end
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
end
