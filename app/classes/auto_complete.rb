# frozen_string_literal: true

#
#  = AutoComplete base class
#
#    auto = AutoCompleteName.new('Agaricus') # ...or...
#    auto = AutoComplete.subclass('name').new('Agaricus')
#    render(:inline => auto.matching_strings.join("\n"))
#
################################################################################

PUNCTUATION = '[ -\x2F\x3A-\x40\x5B-\x60\x7B-\x7F]'

class AutoComplete
  attr_accessor :string, :matches

  class_attribute :limit
  self.limit = 1000

  def self.subclass(type)
    "AutoComplete::For#{type.camelize}".constantize
  rescue StandardError
    raise("Invalid auto-complete type: #{type.inspect}")
  end

  def initialize(string, _params = {})
    self.string = string.to_s.strip_squeeze
  end

  def matching_strings
    self.matches = rough_matches(string[0])
    clean_matches
    minimal_string = refine_matches
    truncate_matches
    [minimal_string] + matches
  end

  private

  def truncate_matches
    return unless matches.length > limit

    matches.slice!(limit..-1)
    matches.push("...")
  end

  def clean_matches
    matches.map! do |str|
      str.sub(/\s*[\r\n]\s*.*/m, "").sub(/\A\s+/, "").sub(/\s+\Z/, "")
    end
    matches.uniq!
  end
end
