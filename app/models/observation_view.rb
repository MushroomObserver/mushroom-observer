# frozen_string_literal: true

# Keep track of when each user last viewed each observation.
class ObservationView < AbstractModel
  belongs_to :observation
  belongs_to :user

  def self.update_view_stats(observation, user)
    return if observation.blank? || user.blank?

    if view = where(observation: observation, user: user).first
      view.update_attributes!(last_view: Time.zone.now)
    else
      create!(observation: observation, user: user, last_view: Time.zone.now)
    end
  end
end
