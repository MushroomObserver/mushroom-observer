# frozen_string_literal: true

class Inat
  # Tidies a name string from iNat -- a provisional or override observation
  # field, or a provisional taxon's name -- before Name.parse_name. It fixes
  # typing slips that don't change what the writer meant: whitespace just
  # inside the quotes, a missing or doubled closing quote, and a missing
  # space between "sp." and the quote (#2892).
  module NameString
    OPEN_TO_CLOSE = { "'" => "'", "‘" => "’", '"' => '"', "“" => "”" }.freeze
    QUOTES = "'‘’\"“”"
    # An opening quote follows whitespace or "sp.", so an apostrophe inside
    # a word (an author's "D'Aguilar") is not one.
    OPENING_QUOTE = /(?<=\A|\s|\.)[#{QUOTES}]/

    # The tidied string, or nil when no MO Name can express it: a hybrid of
    # two provisionals ("×" inside the quotes).
    def self.clean(str)
      str = str.to_s.strip.sub(/\bsp\.(?=[#{QUOTES}])/o, "sp. ")
      return nil if str.empty?

      start = str.index(OPENING_QUOTE)
      return str unless start

      requote(str, start)
    end

    # Name.parse_name of the tidied string. An unranked infraspecific name
    # ("Mycena epipterygia lignicola") takes its rank from the iNat taxon
    # when the taxon is that name.
    def self.parse(str, taxon: nil)
      cleaned = clean(str)
      return nil unless cleaned

      Name.parse_name(cleaned) || parse_with_taxon_rank(cleaned, taxon)
    end

    def self.requote(str, start)
      finish = str.rindex(/[#{QUOTES}]/o)
      inner, rest = if finish > start
                      [str[(start + 1)...finish], str[(finish + 1)..]]
                    else
                      [str[(start + 1)..], ""]
                    end
      inner = inner.gsub(/\A[\s#{QUOTES}]+|[\s#{QUOTES}]+\z/o, "")
      return nil if inner.include?("×")

      open = str[start]
      "#{str[0...start]}#{open}#{inner}#{OPEN_TO_CLOSE.fetch(open, open)}" \
        "#{rest}"
    end
    private_class_method :requote

    def self.parse_with_taxon_rank(str, taxon)
      ranks = Inat::Taxon::INFRASPECIFIC_RANKS
      return nil unless taxon && ranks.include?(taxon[:rank])
      return nil unless str.squeeze(" ").casecmp?(taxon[:name].to_s)

      Name.parse_name(Inat::Taxon.new(taxon).full_name_string)
    end
    private_class_method :parse_with_taxon_rank
  end
end
