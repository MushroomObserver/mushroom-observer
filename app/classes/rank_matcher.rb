# frozen_string_literal: true

# Lighweight class used to get ranks from text strings
# Use:
#   XXX_MATCHERS = [RankMatcher.new(:Rank1, /regexp1/),
#                   ...
#                   RankMatcher.new(:Rankn, /regexpn/)]
#
#   def self.guess_rank(text_name)
#     TEXT_NAME_MATCHERS.find { |matcher| matcher.match?(text_name) }.rank
#   end
#
class RankMatcher
  attr_reader :pattern, :rank

  def initialize(rank, pattern)
    @rank = rank
    @pattern = pattern
  end

  def match?(str)
    str.match?(@pattern)
  end
end

# Match text_name to rank
TEXT_NAME_MATCHERS = [
  RankMatcher.new(:Group,      / (group|clade|complex)$/),
  RankMatcher.new(:Form,       / f\. /),
  RankMatcher.new(:Variety,    / var\. /),
  RankMatcher.new(:Subspecies, / subsp\. /),
  RankMatcher.new(:Stirps,     / stirps /),
  RankMatcher.new(:Subsection, / subsect\. /),
  RankMatcher.new(:Section,    / sect\. /),
  # TODO: Can delete "subgenus" from the next line
  # after all subgenus Names are converted to "subg."
  RankMatcher.new(:Subgenus,   / (sub\.|subgenus) /),
  RankMatcher.new(:Species,    / /),
  RankMatcher.new(:Family,     /^\S+aceae$/),
  RankMatcher.new(:Family,     /^\S+ineae$/),     # :Suborder
  RankMatcher.new(:Order,      /^\S+ales$/),
  RankMatcher.new(:Order,      /^\S+mycetidae$/), # :Subclass
  RankMatcher.new(:Class,      /^\S+mycetes$/),
  RankMatcher.new(:Class,      /^\S+mycotina$/),  # :Subphylum
  RankMatcher.new(:Phylum,     /^\S+mycota$/),
  RankMatcher.new(:Phylum,     /^Fossil-/),
  RankMatcher.new(:Genus,      //)                # match anything else
].freeze

# All abbrevisations for a given rank
# Used by RANK_FROM_ABBREV_MATCHERS and in app/models/name/parse.rb
SUBG_ABBR    = / subgenus | subg\.?                      /xi.freeze
SECT_ABBR    = / section | sect\.?                       /xi.freeze
SUBSECT_ABBR = / subsection | subsect\.?                 /xi.freeze
STIRPS_ABBR  = / stirps                                  /xi.freeze
SP_ABBR      = / species | sp\.?                         /xi.freeze
SSP_ABBR     = / subspecies | subsp\.? | ssp\.? | s\.?   /xi.freeze
VAR_ABBR     = / variety | var\.? | v\.?                 /xi.freeze
F_ABBR       = / forma | form\.? | fo\.? | f\.?          /xi.freeze
GROUP_ABBR   = / group | gr\.? | gp\.? | clade | complex /xi.freeze

# Matcher abbreviation to rank
RANK_FROM_ABBREV_MATCHERS = [
  RankMatcher.new(:Subgenus,   SUBG_ABBR),
  RankMatcher.new(:Section,    SECT_ABBR),
  RankMatcher.new(:Subsection, SUBSECT_ABBR),
  RankMatcher.new(:Stirps,     STIRPS_ABBR),
  RankMatcher.new(:Subspecies, SSP_ABBR),
  RankMatcher.new(:Variety,    VAR_ABBR),
  RankMatcher.new(:Form,       F_ABBR),
  RankMatcher.new(nil,         //) # match anything else
].freeze
