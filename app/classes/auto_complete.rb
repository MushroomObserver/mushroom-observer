# frozen_string_literal: true

#
#  = AutoComplete base class
#
#    auto = AutoCompleteName.new('Agaricus') # ...or...
#    auto = AutoComplete.subclass('name').new('Agaricus')
#    render(:inline => auto.matching_strings.join("\n"))
#
################################################################################

class AutoComplete
  attr_accessor :string, :matches, :all, :whole

  PUNCTUATION = '[ -\x2F\x3A-\x40\x5B-\x60\x7B-\x7F]'

  def limit
    1000
  end

  def self.subclass(type)
    "AutoComplete::For#{type.camelize}".constantize
  rescue StandardError
    raise("Invalid auto-complete type: #{type.inspect}")
  end

  def initialize(params = {})
    self.string = params[:string].to_s.strip_squeeze
    self.all = params[:all].present?
    self.whole = params[:whole].present?
  end

  def matching_records
    # unless 'whole', use the first letter of the string to define the matches
    token = whole ? string : string[0]
    self.matches = rough_matches(token)
    clean_matches
    return matches if all

    minimal_string = refine_matches # defined in subclass
    truncate_matches
    # [minimal_string] + matches
    [[minimal_string, nil]] + matches
    # Could be nice for JSON:
    # this will return a hash indexed by the IDs of the records
    # ([[minimal_string, 0]] + matches).to_h(&:reverse)
  end

  private

  def clean_matches
    # matches.map! do |str|
    #   str.sub(/\s*[\r\n]\s*.*/m, "").sub(/\A\s+/, "").sub(/\s+\Z/, "")
    # end
    matches.map! do |str, id|
      clean = str.sub(/\s*[\r\n]\s*.*/m, "").sub(/\A\s+/, "").sub(/\s+\Z/, "")
      [clean, id]
    end
    matches.uniq!
  end

  def truncate_matches
    return unless matches.length > limit

    matches.slice!(limit..-1)
    # matches.push("...")
    matches.push(["...", nil])
  end
end
