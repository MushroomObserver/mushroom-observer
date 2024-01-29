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
