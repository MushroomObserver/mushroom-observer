# frozen_string_literal: true

class Autocomplete::ForClade < Autocomplete::ByString
  attr_accessor :min_rank

  def initialize(params = {})
    super
    self.min_rank = valid_min_rank(params[:min_rank])
  end

  def rough_matches(letter)
    # (this sort puts higher rank on top)
    clades = Name.with_correct_spelling.with_rank_above(min_rank).
             where(Name[:text_name].matches("#{letter}%")).order(rank: :desc).
             select(:text_name, :rank, :id, :deprecated)

    matches_array(clades)
  end

  # Doesn't make sense to have exact match for clades
  # def exact_match(string)
  #   clade = Name.with_correct_spelling.with_rank_above_genus.
  #           where(Name[:text_name].eq(string)).first
  #   return [] unless clade

  #   matches_array([clade])
  # end

  # Turn the instances into hashes
  def matches_array(clades)
    matches = clades.map do |clade|
      clade = clade.attributes.symbolize_keys
      clade[:deprecated] = clade[:deprecated] || false
      clade[:name] = clade[:text_name]
      clade.except(:text_name, :rank)
    end
    matches.sort_by! { |clade| clade[:name] }
    matches.uniq { |clade| clade[:name] }
  end

  private

  # A caller (e.g. the inherit-classification parent field) can scope
  # suggestions to the subject Name's rank, not just above genus.
  # Falls back to :Genus for an absent/invalid value -- untrusted
  # request params shouldn't reach the rank comparison unvalidated.
  # Name.all_ranks is String-based; normalize to String to validate a
  # Symbol caller (e.g. a Ruby caller passing :Family) correctly, but
  # always return a Symbol so min_rank's type stays consistent either
  # way.
  def valid_min_rank(value)
    return :Genus unless Name.all_ranks.include?(value.to_s)

    value.to_s.to_sym
  end
end
