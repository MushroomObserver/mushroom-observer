class MoApiKey < ActiveRecord::Base
  belongs_to :user
  before_create :provide_defaults

  KEY_LENGTH = 32

  def provide_defaults
    self.created ||= Time.now
    self.last_used ||= nil
    self.num_uses ||= 0
    self.user_id ||= User.current_id
    self.key ||= self.class.new_key
    self.notes ||= ''
  end

  def touch!
    update_attributes!(
      :last_used => Time.now,
      :num_uses => num_uses + 1
    )
  end 

  def self.new_key
    String.random(KEY_LENGTH)
  end

  def validate
    if notes.blank?
      errors.add(:notes, :account_api_keys_no_notes.t)
    end
  end
end
