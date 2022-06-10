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
class Name::RankMatcher
  attr_reader :pattern, :rank

  def initialize(rank, pattern)
    @rank = rank
    @pattern = pattern
  end

  def match?(str)
    str.match?(@pattern)
  end
end
