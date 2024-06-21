# frozen_string_literal: true

#
#  = AutoComplete base class
#
#    results = AutoCompleteName.new(string: 'Agaricus') # ...or...
#    results = AutoComplete.subclass('name').new(string: 'Agaricus')
#    render(json: ActiveSupport::JSON.encode(results)
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

  # returns an array of { name:, id: } objects
  def matching_records
    # unless 'whole', use the first letter of the string to define the matches
    token = whole ? string : string[0]
    self.matches = rough_matches(token)
    clean_matches

    unless all
      minimal_string = refine_token # defined in subclass
      matches.unshift([minimal_string, 0])
      truncate_matches
    end

    matches.map { |name, id| { name:, id: } }
  end

  private

  def clean_matches
    matches.map! do |str, id|
      clean = str.sub(/\s*[\r\n]\s*.*/m, "").sub(/\A\s+/, "").sub(/\s+\Z/, "")
      [clean, id]
    end
    matches.uniq!
  end

  def truncate_matches
    return unless matches.length > limit

    matches.slice!(limit..-1)
    matches.push(["...", nil])
  end
end
