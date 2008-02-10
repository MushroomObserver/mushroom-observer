# Copyright (c) 2006 Nathan Wilson
# Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php

# Public:
#   Vote.confidence_menu    Structures needed by the form helper,
#   Vote.agreement_menu     select(), to create a pulldown menu.
#
#   Vote.confidence(value)  Find vote closest in value to the
#   Vote.agreement(value)   given one.  Returns string.
#   confidence
#   agreement
#
#   Vote.delete_vote    Value of the special "delete" vote.
#   Vote.minimum_vote   Value of the weakest nonzero vote.
#   Vote.min_neg_vote   Value of the least negative vote.
#   Vote.average_vote   Value of the neutral vote.
#   Vote.min_pos_vote   Value of the least positive vote.
#   Vote.next_best_vote Value of the next-to-best vote.
#   Vote.maximum_vote   Value of the strongest vote.
#   Note: larger vote value indicates stronger agreement
#
# Protected:
#   Vote.lookup_value(val, list)    Used by confidence/agreement().

class Vote < ActiveRecord::Base
  belongs_to :user
  belongs_to :naming

  CONFIDENCE_VALS = [
    [ :vote_confidence_100, 100 ],
    [ :vote_confidence_80,   80 ],
    [ :vote_confidence_60,   60 ],
    [ :vote_confidence_40,   40 ],
    [ :vote_confidence_20,   20 ],
    [ :vote_confidence_0,     0 ]
  ]

  AGREEMENT_VALS = [
    [ :vote_no_opinion,     -1 ],
    [ :vote_agreement_100, 100 ],
    [ :vote_agreement_80,   80 ],
    [ :vote_agreement_60,   60 ],
    [ :vote_agreement_40,   40 ],
    [ :vote_agreement_20,   20 ],
    [ :vote_agreement_0,     0 ]
  ]

  # Various useful vote values.
  DELETE_VOTE    = -1
  MINIMUM_VOTE   = 0
  MIN_NEG_VOTE   = 40
  AVERAGE_VOTE   = 50
  MIN_POS_VOTE   = 60
  NEXT_BEST_VOTE = 80
  MAXIMUM_VOTE   = 100

  # External access to the constants above.
  def self.delete_vote;    DELETE_VOTE;    end # This is used to mean "delete my vote". 
  def self.minimum_vote;   MINIMUM_VOTE;   end # Weakest nonzero vote.
  def self.min_neg_vote;   MIN_NEG_VOTE;   end # Least-negative vote.
  def self.average_vote;   AVERAGE_VOTE;   end # Neutral vote.
  def self.min_pos_vote;   MIN_POS_VOTE;   end # Least-positive vote.
  def self.next_best_vote; NEXT_BEST_VOTE; end # Next-to-best vote.
  def self.maximum_vote;   MAXIMUM_VOTE;   end # Strongest vote.

  # Return list of menu options.
  def self.confidence_menu; CONFIDENCE_VALS; end
  def self.agreement_menu;  AGREEMENT_VALS;  end

  # Find label of closest value in the enumerated lists above.
  def self.confidence(val); return Vote.lookup_value(val, CONFIDENCE_VALS);        end
  def self.agreement(val);  return Vote.lookup_value(val, AGREEMENT_VALS);         end
  def confidence;           return Vote.lookup_value(self.value, CONFIDENCE_VALS); end
  def agreement;            return Vote.lookup_value(self.value, AGREEMENT_VALS);  end

  protected

  # Find label of closest value in a given enumerated lists.
  def self.lookup_value(val, list)
    last_pair = nil
    for pair in list
      if pair[1] >= 0
        if !last_pair.nil? && val > (last_pair[1] + pair[1]) / 2
          return last_pair[0]
        end
        last_pair = pair
      end
    end
    return last_pair[0]
  end

  validates_presence_of :naming, :user
  validates_each :value do |record, attr, value|
    if value.nil?
      record.errors.add(attr, "can't be blank") 
    elsif record.value_before_type_cast.to_s !~ /^[+-]?\d+(\.\d+)?$/
      record.errors.add(attr, "is not a number") 
    elsif value < MINIMUM_VOTE || value > MAXIMUM_VOTE
      record.errors.add(attr, "out of range") 
    end
  end
end
