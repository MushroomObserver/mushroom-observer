# frozen_string_literal: true

# Keep track of when each user last viewed each observation, as well as
# whether they've marked it as `reviewed` (in help identify) or voted on
# a naming of that obs (indicating reviewed)

#  == Attributes
#
#  observation_id::         ID of the observation.
#  user_id::                User that  it.
#  last_view::              Date/time it was last accessed.
#  reviewed::               Boolean.

class ObservationView < AbstractModel
  # Surface N+1s on `observation_view.observation` / `.user`; every
  # caller must eager-load these.
  self.strict_loading_by_default = true

  belongs_to :observation
  belongs_to :user

  def self.update_view_stats(obs_id, user_id, reviewed = nil)
    return if obs_id.blank? || user_id.blank?

    args = { observation_id: obs_id, user_id: user_id,
             last_view: Time.zone.now }
    args[:reviewed] = reviewed unless reviewed.nil?

    # Either way, this returns the observation view instance
    if (view = find_by(observation_id: obs_id, user_id: user_id))
      view.update!(args)
      view
    else
      create!(args)
    end
  end

  # Pick the FK directly so strict_loading on `view.observation`
  # isn't a problem — one extra `find_by` is cheaper than an extra
  # `includes` per call.
  def self.last(user)
    obs_id = where(user:).order(last_view: :desc).pick(:observation_id)
    obs_id && Observation.find_by(id: obs_id)
  end

  def self.previous(user, observation)
    obs_id = where(user:).where.not(observation:).
             order(last_view: :desc).pick(:observation_id)
    obs_id && Observation.find_by(id: obs_id)
  end
end
