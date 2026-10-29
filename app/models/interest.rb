# frozen_string_literal: true

#
#  = Interest Model
#
#  Simple model for registering interest in arbitrary objects.  Any User may
#  register either positive interest ("watch") or negative interest ("ignore")
#  in any object.
#
#  In practice this means that the User receives some sort of notification
#  whenever anything changes or happens to objects that they are watching; and
#  that they stop receiving any sort of notifications about objects they are
#  ignoring (even if they own it, for example).
#
#  Currently this functionality is implemented for:
#
#  * Location
#  * LocationDescription
#  * Name
#  * NameDescription
#  * Observation
#  * Project
#
#  == Attributes
#
#  id::             Locally unique numerical id, starting at 1.
#  updated_at::     Date/time it was last updated.
#  user::           User that created it.
#  target::         Object in question.
#  state::          Enum: "watching" or "ignoring".
#
#  == Class methods
#
#  # find_all_by_target::   Find all Interests for a given object.
#  where_target::   Find all Interests for a given object.
#
#  == Instance methods
#
#  summary::        Human-readable summary of state.
#  text_name::      Alias for +summary+ for debugging.
#
#  == Callbacks
#
#  None.
#
#  == Polymorphism
#
#  See comments under Comment.
#
################################################################################
#
class Interest < AbstractModel
  belongs_to :user
  belongs_to :target, polymorphic: true

  # Backed by the existing boolean column -- Rails' enum macro maps
  # directly onto raw true/false values, so no migration is needed.
  enum :state, { ignoring: false, watching: true }

  # Maintain this Array of all models (targets) which take interests.
  ALL_TYPES = [
    Location, LocationDescription, Name, NameDescription, NameTracker,
    Observation, Project, SpeciesList
  ].freeze

  # Returns Array of all valid +target_type+ values (Symbols).
  ALL_TYPE_TAGS = ALL_TYPES.map { |type| type.to_s.underscore.to_sym }.freeze

  # Returns Array of all valid +state+ values (Symbols), for
  # `Query::Interests`.
  ALL_STATE_TAGS = states.keys.map(&:to_sym).freeze

  # Allow explicit joining for all polymorphic associations,
  # e.g. `Interest.joins(:location).where(target_id: 29513)`,
  # by restating the association below with a scope.
  # https://veelenga.github.io/joining-polymorphic-associations/
  ALL_TYPE_TAGS.each do |model_tag|
    belongs_to model_tag, lambda {
      where(interests: { target_type: model_tag.to_s.camelize })
    }, foreign_key: "target_id", inverse_of: :interests
  end

  scope :for_user, ->(user) { where(user: user) }
  # MySQL's default collation is case-insensitive, so lowercase tags
  # (:observation) match the capitalized target_type column values
  # ("Observation") without translation -- same pattern as
  # Comment.types.
  scope :types, ->(types) { where(target_type: types) }
  scope :state, ->(tag) { where(state: tag) }

  validates :target_type, inclusion: { in: ALL_TYPES.map(&:to_s) }

  # Find all Interests associated with a given object.  This should really be
  # created magically like all the other find_all_by_xxx methods, but the
  # polymorphism messes it up.
  # def self.find_all_by_target(obj)
  def self.where_target(obj)
    return unless obj.is_a?(ActiveRecord::Base) && obj.id

    # find_all_by_target_type_and_target_id(obj.class.to_s, obj.id)
    where(target_type: obj.class.to_s, target_id: obj.id)
  end

  # Mutates `recipients` in place: pushes each watcher's user, deletes
  # each ignorer's user -- even if present for another reason (e.g.
  # the target's owner). Returns `recipients`.
  def self.update_recipients!(interests, recipients)
    interests.each do |interest|
      if interest.watching?
        recipients.push(interest.user)
      else
        recipients.delete(interest.user)
      end
    end
    recipients
  end

  # `user` (this Interest's owner) is the only one who ever sees this,
  # via their own Interests index page.
  def target_format_name
    target.unique_format_name(user)
  end

  ##############################################################################

  protected

  validate :check_requirements
  # In practice every real caller already sets `user:`/`.user =`
  # explicitly; current_user is only a fallback for this check.
  def check_requirements # :nodoc:
    errors.add(:user, :validate_interest_user_missing) if !user && !current_user

    return unless target_type.to_s.size > 30

    errors.add(:target_type, :validate_interest_object_type_too_long)
  end
end
