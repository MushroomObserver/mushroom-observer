class ApiKey < AbstractModel
  belongs_to :user
  before_create :provide_defaults

  KEY_LENGTH = 32

  def self.show_controller
    :account
  end

  def self.index_action
    :api_keys
  end

  def provide_defaults
    self.created_at ||= Time.zone.now
    self.verified ||= nil
    self.last_used ||= nil
    self.num_uses ||= 0
    self.user_id ||= User.current_id
    self.key ||= self.class.new_key
    self.notes ||= ""
  end

  def touch!
    update!(
      last_used: Time.zone.now,
      num_uses: num_uses + 1
    )
  end

  def verify!
    update!(
      verified: Time.zone.now
    )
  end

  def self.new_key
    result = String.random(KEY_LENGTH)
    key = String.random(KEY_LENGTH) while find_by_key(result)
    result
  end

  validate :check_key
  def check_key
    other = self.class.find_by_key(key)
    if other && other.id != id
      # This should never happen.
      errors.add(:key, "api keys must be unique")
    end
    errors.add(:notes, :account_api_keys_no_notes.t) if notes.blank?
  end
end
