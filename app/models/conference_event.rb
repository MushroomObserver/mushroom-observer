# encoding: utf-8

class ConferenceEvent < AbstractModel
  has_many :conference_registrations

  def how_many
    (conference_registrations.map(&:how_many).reduce(&:+) || 0)
  end
end
