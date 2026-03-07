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
