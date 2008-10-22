require 'active_record_extensions'

################################################################################
#
#  Minimal model associated with a Naming that provides the user with the
#  ability to describe how they arrived at that naming.  Each Naming can have
#  zero to many reasons associated with it, although in practice only certain
#  reasons are allowed and no duplicates for a given type are allowed.  Each
#  NamingReason:
#
#  1. has a "reason" or index, describing the type of reason
#  2. has a free-form text field for notes
#  3. belongs to a Naming
#
#  Adding new reasons is just a matter of adding an entry to the REASONS
#  array below.
#
#  Example:
#    nr = NamingReason.new {
#      :naming => naming,
#      :reason => 2,
#      :notes  => "Arora's Mushrooms Demystified, mykoweb.com, Joe Cool"
#    }
#
#  This gives you access to the following read-only fields:
#    nr.label        "Used references"
#    nr.default?     false
#    nr.order        2
#
#  Public Methods:
#    NR.reasons      Array of reason indices.
#    nr.check        Boolean: should checkbox be checked for this reason?
#
################################################################################

class NamingReason < ActiveRecord::Base
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

  # Returns array of reason indices, in proper (display) order.
  def self.reasons
    REASONS.keys.sort { |a,b| REASONS[a][:order] <=> REASONS[b][:order] }
  end

  # "Fake" accessors: retrieves information about reason based on the
  # reason index.
  def label
    REASONS[reason][:label]
  end
  def default?
    REASONS[reason][:default]
  end
  def order
    REASONS[reason][:order]
  end

  # State of checkbox for this reason in form.
  # Returns: boolean.
  # (Name and prototype is dictated by some HTML form helper in rails.)
  def check
    self.notes.nil? ? false : true
  end

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
