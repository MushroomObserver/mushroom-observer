# Copyright (c) 2006 Nathan Wilson
# Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php

require 'active_record_extensions'

# NamingReasons are mininal objects associated with a Naming that provide the
# user the describe how they arrived at that naming.  Each reason can have
# zero to many reasons associated with it, although in practice only certain
# reasons are allowed and no duplicates for a given type are allowed.
# 
# Each reason has a "reason" or "index", a reference to the Naming, and a
# free-form text field for notes.  The "index" describes the type of reason;
# it # is the outer key of the static REASONS structure (see below).  For
# example, reason 2 is used to include a list of the references used: 
#
#   nr = NamingReason.new {
#     :naming => naming,
#     :reason => 2,
#     :notes  => "Arora's Mushrooms Demystified, mykoweb.com, Joe Cool"
#   }
#
# This gives you access to the following read-only fields:
#
#   nr.reason       # 2
#   nr.label        # "Used references"
#   nr.default?     # false
#   nr.order        # 2
# 
# Methods:
#   NamingReason.reasons  Array of reason indices.
#   reason.label          Text string to use as label in displays, forms, etc.
#   reason.default?       Boolean: is this reason to be included by default?
#   reason.order          Integer: use this to sort reasons for display.
#   reason.check          Boolean: should checkbox be checked for this reason?

class NamingReason < ActiveRecord::Base
  belongs_to :naming

  attr_display_names({
    "reason" => "type"
  })

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

  validates_presence_of :naming, :reason
  validates_inclusion_of :reason, :in => REASONS.keys,
    :message => "is not recognized"
end
