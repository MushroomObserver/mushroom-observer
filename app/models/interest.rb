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
#  state::          Either true (watching) or false (ignoring).
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
  belongs_to :target, polymorphic: true
  belongs_to :user

  scope :for_user,
        ->(user) { where(user: user) }

  ALL_INTEREST_TYPES = %w[
    Location
    Name
    NameTracker
    Observation
    Project
    SpeciesList
  ].freeze

  validates :target_type, inclusion: { in: ALL_INTEREST_TYPES }

  # Returns Array of all models (Classes) which take interests.
  def self.all_types
    types = ALL_INTEREST_TYPES.dup
    types.map(&:constantize)
  end

  # Returns Array of all valid +target_type+ values (Symbol's).
  def self.all_type_tags
    types = ALL_INTEREST_TYPES.dup
    types.map { |t| t.underscore.to_sym }
  end

  # Find all Interests associated with a given object.  This should really be
  # created magically like all the other find_all_by_xxx methods, but the
  # polymorphism messes it up.
  # def self.find_all_by_target(obj)
  def self.where_target(obj)
    return unless obj.is_a?(ActiveRecord::Base) && obj.id

    # find_all_by_target_type_and_target_id(obj.class.to_s, obj.id)
    where(target_type: obj.class.to_s, target_id: obj.id)
  end

  # To be compatible with NameTracker need to have summary string:
  #
  #   "Watching Observation: Amanita virosa"
  #   "Ignoring Location: Albion, California, USA"
  #
  def summary
    return target.summary if target && (target_type == "NameTracker")

    (state ? :WATCHING.l : :IGNORING.l) + " " +
      target_type.underscore.to_sym.l + ": " +
      (target ? target.unique_format_name : "--")
  end
  alias text_name summary

  ##############################################################################

  protected

  validate :check_requirements
  def check_requirements # :nodoc:
    if !user && !User.current
      errors.add(:user, :validate_interest_user_missing.t)
    end

    return unless target_type.to_s.size > 30

    errors.add(:target_type, :validate_interest_object_type_too_long.t)
  end
end
