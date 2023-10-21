# frozen_string_literal: true

# Keep track of when each user last viewed each observation.
class ObservationView < AbstractModel
  belongs_to :observation
  belongs_to :user

  def self.update_view_stats(obs_id, user_id)
    return if obs_id.blank? || user_id.blank?

    # Either way, this returns the observation view so you can do other stuff
    # like mark it reviewed
    if (view = find_by(observation_id: obs_id, user_id: user_id))
      view.update!(last_view: Time.zone.now)
      view
    else
      create!(observation_id: obs_id, user_id: user_id,
              last_view: Time.zone.now)
    end
  end
end
