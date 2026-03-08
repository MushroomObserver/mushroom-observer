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
#  default_observation_id::   FK to the default Observation
#  has_specimen::             cached: true if any observation has specimen
#  created_at::               timestamp
#  updated_at::               timestamp
#
class Occurrence < AbstractModel
  MAX_OBSERVATIONS = 10

  belongs_to :user
  belongs_to :default_observation, class_name: "Observation"
  has_many :observations, dependent: :nullify

  validates :default_observation, presence: true
  validate :default_observation_must_belong_to_occurrence, on: :update
  validate :observation_count_within_limits, on: :update

  # Recompute cached has_specimen from associated observations.
  def recompute_has_specimen!
    update!(has_specimen: observations.where(specimen: true).exists?)
  end

  # Auto-destroy if reduced to fewer than 2 observations.
  def destroy_if_incomplete!
    destroy! if observations.count < 2
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
  def self.create_manual(default_obs, selected_obs, user)
    check_field_slip_conflicts!(selected_obs)
    check_max_observations!(selected_obs)

    occurrences = selected_obs.filter_map(&:occurrence).uniq
    if occurrences.any?
      merge_into_manual(occurrences, default_obs, selected_obs, user)
    else
      build_new(default_obs, selected_obs, user)
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
  def self.merge_into_manual(occurrences, default_obs, all_obs, _user)
    keeper = occurrences.shift
    occurrences.each { |occ| merge!(keeper, occ) }
    all_obs.each do |obs|
      next if obs.occurrence_id == keeper.id

      obs.update!(occurrence: keeper)
    end
    keeper.update!(default_observation: default_obs)
    keeper.recompute_has_specimen!
    keeper
  end
  private_class_method :merge_into_manual

  # Build and persist a brand-new occurrence with the given
  # observations.
  def self.build_new(default_obs, all_obs, user)
    transaction do
      occ = create!(user: user, default_observation: default_obs)
      all_obs.each { |obs| obs.update!(occurrence: occ) }
      occ.recompute_has_specimen!
      occ
    end
  end
  private_class_method :build_new

  private

  def default_observation_must_belong_to_occurrence
    return if default_observation_id.blank?
    return if default_observation_belongs?

    errors.add(:default_observation,
               "must belong to this occurrence")
  end

  def default_observation_belongs?
    if observations.loaded?
      observations.any? { |o| o.id == default_observation_id }
    else
      observations.where(id: default_observation_id).exists?
    end
  end

  def observation_count_within_limits
    count = observations.count
    return if count.between?(2, MAX_OBSERVATIONS)

    if count < 2
      errors.add(:observations, "must have at least 2 observations")
    else
      errors.add(:observations,
                 "must have at most #{MAX_OBSERVATIONS} observations")
    end
  end
end
