# frozen_string_literal: true

#
#  = Autocomplete base class
#
#    results = AutocompleteName.new(string: 'Agaricus') # ...or...
#    results = Autocomplete.subclass('name').new(string: 'Agaricus')
#    render(json: ActiveSupport::JSON.encode(results)
#
################################################################################

class Autocomplete
  attr_accessor :string, :matches, :all, :whole

  PUNCTUATION = '[ -\x2F\x3A-\x40\x5B-\x60\x7B-\x7F]'

  def limit
    5000
  end

  def self.subclass(type)
    "Autocomplete::For#{type.camelize}".constantize
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
    self.matches = rough_matches(string) || [] # defined in type-subclass
    clean_matches

    unless all
      minimal_string = refine_token # defined in subclass
      matches.unshift({ name: minimal_string, id: 0 })
    end
    truncate_matches

    matches
  end

  # returns an array of ONE { name:, id: } object. Uses `exact_match` which
  # is a similar query, but searches using whole string and returns first match.
  def first_matching_record
    self.matches = exact_match(string) || []
    clean_matches

    matches
  end

  private

  def clean_matches
    matches.map! do |obj|
      obj[:name] = obj[:name].sub(/\s*[\r\n]\s*.*/m, "").
                   sub(/\A\s+/, "").sub(/\s+\Z/, "")
      obj
    end
    matches.uniq!
  end

  def truncate_matches
    return unless matches.length > limit

    matches.slice!(limit..-1)
    matches.push({ name: "...", id: nil })
  end
end
