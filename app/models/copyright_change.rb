# frozen_string_literal: true

#
#  = Copyright Change Model
#
#  This model keeps track of change in copyright info in Image objects.
#
#  NOTE: each entry records the state *before* the time given.  If no
#  entries are present, then the copyright has never changed.
#
#  == Attributes
#
#  id::                 Locally unique numerical id, starting at 1.
#  user::               User who made the change.
#  updated_at::         Time the change was made.
#  target::             Object whose copyright info changed.
#  year::               *OLD* year.    \
#  name::               *OLD* name.     ) ©year name, license
#  license::            *OLD* license. /
#
#  == Callbacks
#
#  None.
#
################################################################################

class CopyrightChange < AbstractModel
  belongs_to :user
  belongs_to :license
  belongs_to :target, polymorphic: true

  # Maintain this Array of all models (Classes) which take copyright changes.
  ALL_TYPES = [Image].freeze

  # Returns Array of all valid +target_type+ values (Symbols).
  ALL_TYPE_TAGS = ALL_TYPES.map { |type| type.to_s.underscore.to_sym }.freeze

  # Allow explicit joining for all polymorphic associations,
  # e.g. `CopyrightChange.joins(:image).where(target_id: 29513)`,
  # by restating the association below with a scope.
  # https://veelenga.github.io/joining-polymorphic-associations/
  ALL_TYPE_TAGS.each do |model|
    belongs_to model, lambda {
      where(copyright_changes: { target_type: model.to_s.camelize })
    }, foreign_key: "target_id", inverse_of: :copyright_changes
  end

  ##############################################################################

  protected

  validate :check_requirements
  def check_requirements # :nodoc:
    errors.add(:user, "missing user") unless user
    errors.add(:user, "missing target") unless target
    errors.add(:user, "missing modification time") unless updated_at
    errors.add(:user, "missing license") unless license
  end
end
