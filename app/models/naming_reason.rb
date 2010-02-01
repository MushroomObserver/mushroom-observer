#
#  = Naming Reason Model
#
#  Minimal model associated with a Naming that provides the user with the
#  ability to describe how they arrived at that Naming.  Each Naming can have
#  zero to many reasons associated with it, although in practice only certain
#  reasons are allowed and no duplicates for a given type are allowed.
#
#  Adding new reasons is just a matter of adding an entry to the REASONS
#  array below.
#
#  == Usage
#
#    # Attach new reason to an existing Naming:
#    nr = NamingReason.new {
#      :naming => naming,
#      :reason => 2,
#      :notes  => "Arora's Mushrooms Demystified, mykoweb.com, Joe Cool"
#    }
#
#  == Attributes
#
#  id::           Locally unique numerical id, starting at 1.
#  modified::     Date/time it was last modified.
#  naming::       Naming it is attached to.
#  reason::       Reason (integer).
#  notes::        Notes (variable-length string).
#
#  == Class methods
#
#  all_reasons::  Array of reason indices.
#
#  == Instance methods
#
#  label::        Localization string for this reason.
#  default?::     Is this reason set by default if none given by user?
#  order::        Order this reason should appear in: integer starting at 1.
#  check::        Boolean: should checkbox be checked for this reason?
#  text_name::    Alias for +label+ for debugging.
#
#  == Callbacks
#
#  None.
#
#
################################################################################

class NamingReason < AbstractModel
  belongs_to :naming

  # Outside key is the integer stored in database as "reason".
  # Inside hash describes the given reason.
  REASONS = {
    1 => {
      :label   => :naming_reason_label_1,
      :default => true,
      :order   => 1
    },
    2 => {
      :label   => :naming_reason_label_2,
      :default => false,
      :order   => 2
    },
    3 => {
      :label   => :naming_reason_label_3,
      :default => false,
      :order   => 3
    },
    4 => {
      :label   => :naming_reason_label_4,
      :default => false,
      :order   => 4
    }
  }

  # List of reasons in preferred (display) order.  Returns Array of Integer's.
  def self.all_reasons
    REASONS.keys.sort_by {|x| REASONS[x][:order]}
  end

  # Get localization string for this reason.
  #
  #   puts naming_reason.label.l
  #
  def label
    REASONS[reason][:label]
  end

  # Return +label+ as plain text for debugging.
  def text_name
    label.l
  end

  # Is this reason set by default if none given by user?
  def default?
    REASONS[reason][:default]
  end

  # Order this reason should appear in: integer starting at 1.
  #
  #   reasons.sort_by(&:order)
  #
  def order
    REASONS[reason][:order]
  end

  # State of checkbox for this reason in HTML form.
  # (Name and prototype is dictated by some HTML form helper in rails.)
  def check
    notes ? true : false
  end

################################################################################

protected

  def validate # :nodoc:
    if !self.naming
      errors.add(:naming, :validate_naming_reason_naming_missing.t)
    end

    if !REASONS.keys.include?(self.reason)
      errors.add(:reason, :validate_naming_reason_reason_invalid.t)
    end
  end
end
