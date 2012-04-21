class ConferenceEvent < AbstractModel
  has_many :conference_registrations
  
  def how_many
    return (self.conference_registrations.map(&:how_many).reduce(&:+) or 0)
  end
end
