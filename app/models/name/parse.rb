# frozen_string_literal: true

# Usage: in class Name, `extend Parse`, not `include Parse`.
# Extending makes these module methods into class methods of Name.
module Name::Parse
  # RankMatcher:: Lighweight class used to get ranks from text strings
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

  # All abbrevisations for a given rank
  # Used by RANK_FROM_ABBREV_MATCHERS and in app/models/name/parse.rb
  SUBG_ABBR    = / subgenus | subgen\.? | subg\.?          /xi
  SECT_ABBR    = / section | sect\.?                       /xi
  SUBSECT_ABBR = / subsection | subsect\.?                 /xi
  STIRPS_ABBR  = / stirps                                  /xi
  SP_ABBR      = / species | sp\.?                         /xi
  SSP_ABBR     = / subspecies | subsp\.? | ssp\.? | s\.?   /xi
  VAR_ABBR     = / variety | var\.? | v\.?                 /xi
  F_ABBR       = / forma | form\.? | fo\.? | f\.?          /xi
  GROUP_ABBR   = / group | gr\.? | gp\.? | clade | complex /xi

  PROV_RANKS = {
    "Gen." => "Genus",
    "Fam." => "Family",
    "Ord." => "Order",
    "Cl." => "Class",
    "Phy." => "Plylum"
  }.freeze

  RANKS_BELOW_GENUS = ["subg.", "subgen.", "subgenus",
                       "sect.", "sect",
                       "subsect.", "subsect", "stirps", "sp.",
                       "subsp.", "ssp.", "var.", "var", "v.", "f."].freeze

  # Match text_name to rank
  TEXT_NAME_MATCHERS = [
    RankMatcher.new("Group",      / (group|clade|complex)$/),
    RankMatcher.new("Form",       / f\. /),
    RankMatcher.new("Variety",    / var\. /),
    RankMatcher.new("Subspecies", / subsp\. /),
    RankMatcher.new("Stirps",     / stirps /),
    RankMatcher.new("Subsection", / subsect\. /),
    RankMatcher.new("Section",    / sect\. /),
    RankMatcher.new("Subgenus",   / subg\. /),
    RankMatcher.new("Species",    / /),
    RankMatcher.new("Family",     /^\S+aceae$/),
    RankMatcher.new("Family",     /^\S+ineae$/), # :Suborder
    RankMatcher.new("Order",      /^\S+ales$/),
    RankMatcher.new("Order",      /^\S+mycetidae$/), # :Subclass
    RankMatcher.new("Class",      /^\S+mycetes$/),
    RankMatcher.new("Class",      /^\S+mycotina$/), # :Subphylum
    RankMatcher.new("Phylum",     /^\S+mycota$/),
    RankMatcher.new("Phylum",     /^Fossil-/),
    RankMatcher.new("Genus",      //) # match anything else
  ].freeze

  # Matcher abbreviation to rank
  RANK_FROM_ABBREV_MATCHERS = [
    RankMatcher.new("Subgenus",   SUBG_ABBR),
    RankMatcher.new("Section",    SECT_ABBR),
    RankMatcher.new("Subsection", SUBSECT_ABBR),
    RankMatcher.new("Stirps",     STIRPS_ABBR),
    RankMatcher.new("Subspecies", SSP_ABBR),
    RankMatcher.new("Variety",    VAR_ABBR),
    RankMatcher.new("Form",       F_ABBR),
    RankMatcher.new(nil,          //) # match anything else
  ].freeze

  AUCT_ABBR    = / auct\.? /xi
  INED_ABBR    = / in\s?ed\.? /xi
  NOM_ABBR     = / nomen | nom\.? /xi
  COMB_ABBR    = / combinatio | comb\.? /xi
  SENSU_ABBR   = / sensu?\.? /xi
  NOV_ABBR     = / nova | novum | nov\.? /xi
  PROV_ABBR    = / provisional | prov\.? /xi
  CRYPT_ABBR   = / crypt\.? \s temp\.? /xi

  ANY_SUBG_ABBR   = / #{SUBG_ABBR} | #{SECT_ABBR} | #{SUBSECT_ABBR} |
                      #{STIRPS_ABBR} /x
  ANY_SSP_ABBR    = / #{SSP_ABBR} | #{VAR_ABBR} | #{F_ABBR} /x
  ANY_NAME_ABBR   = / #{ANY_SUBG_ABBR} | #{SP_ABBR} | #{ANY_SSP_ABBR} |
                      #{GROUP_ABBR} /x
  ANY_AUTHOR_ABBR = / (?: #{AUCT_ABBR} | #{INED_ABBR} | #{NOM_ABBR} |
                          #{COMB_ABBR} | #{SENSU_ABBR} | #{CRYPT_ABBR} )
                      (?:\s|$) /x
  ANY_RANK_ABBR   = / #{ANY_SUBG_ABBR} | #{SP_ABBR} | #{ANY_SSP_ABBR} /x

  UPPER_WORD = /
                [A-Z][a-zë-]*[a-zë0-9] | ['"][A-Z][a-zë\-.]*[a-zë0-9]['"]
  /x

  UNQUOTED_PROV = /^(?:[a-z]+-)*[A-Z][A-Z0-9]*$/
  LOWER_WORD = /
    (?!(?:sensu|van|de)\b) [a-z][a-zë-]*[a-zë] |
    (?:sp\. \s)?['"]\w[\wë\-. ]*[\wë.]['"] |
    (?:sp\. \s)?(?:[a-z]+-)*[A-Z][A-Z0-9]* /x
  BINOMIAL   = / #{UPPER_WORD} \s #{LOWER_WORD} /x
  LOWER_WORD_OR_SP_NOV = / (?! sp\s|sp$|species) #{LOWER_WORD} |
                           sp\.\s\S*\d\S* /x

  # Matches the last epithet in a (standardized) name,
  # including preceding abbreviation if there is one.
  LAST_PART = / (?: \s[a-z]+\.? )? \s \S+ $/x

  AUTHOR_START = /
    #{ANY_AUTHOR_ABBR} |
    van\s | d[eu]\s |
    [A-ZÀÁÂÃÄÅÆÇĐÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞČŚŠ(] |
    ['"][^a-z\s]
  /x

  # AUTHOR_PAT is separate from, and can't include GENUS_OR_UP_TAXON, etc.
  #   AUTHOR_PAT ensures "sp", "ssp", etc., aren't included in author.
  #   AUTHOR_PAT removes the author first thing.
  # Then the other parsers have a much easier job.
  AUTHOR_PAT =
    /^
      ( ['"]?
        #{UPPER_WORD}
        (?:
            # >= 1 of (rank Epithet)
            \s     #{ANY_SUBG_ABBR} \s #{UPPER_WORD}
            (?: \s #{ANY_SUBG_ABBR} \s #{UPPER_WORD} )* ['"]?
          |
            \s (?! #{AUTHOR_START} | #{ANY_SUBG_ABBR} ) #{LOWER_WORD}
            (?: \s #{ANY_SSP_ABBR} \s #{LOWER_WORD} )* ['"]?
          |
            ['"]? \s #{SP_ABBR}
        )?
      )
      ( \s (?! #{ANY_NAME_ABBR} \s ) #{AUTHOR_START}.* )
    $/x

  # Disable cop to allow alignment and easier comparison of regexps
  # rubocop:disable Layout/LineLength

  PROV_RANK_PREFIX = /[A-Z][a-z]+\.\ /x

  # Taxa without authors (for use by GROUP PAT)
  GENUS_OR_UP_TAXON = /(#{PROV_RANK_PREFIX})?(['"]? (?:Fossil-)? #{UPPER_WORD} ['"]?) (?: \s #{SP_ABBR} )?/x # ([A-Z][a-z]+\. )?
  SUBGENUS_TAXON    = /(#{PROV_RANK_PREFIX})?(['"]? #{UPPER_WORD} \s (?: #{SUBG_ABBR} \s #{UPPER_WORD}) ['"]?)/x
  SECTION_TAXON     = /(#{PROV_RANK_PREFIX})?(['"]? #{UPPER_WORD} \s (?: #{SUBG_ABBR} \s #{UPPER_WORD} \s)?
                       (?: #{SECT_ABBR} \s #{UPPER_WORD}) ['"]?)/x
  SUBSECTION_TAXON  = /(#{PROV_RANK_PREFIX})?(['"]? #{UPPER_WORD} \s (?: #{SUBG_ABBR} \s #{UPPER_WORD} \s)?
                       (?: #{SECT_ABBR} \s #{UPPER_WORD} \s)?
                       (?: #{SUBSECT_ABBR} \s #{UPPER_WORD}) ['"]?)/x
  STIRPS_TAXON      = /(#{PROV_RANK_PREFIX})?(['"]? #{UPPER_WORD} \s (?: #{SUBG_ABBR} \s #{UPPER_WORD} \s)?
                       (?: #{SECT_ABBR} \s #{UPPER_WORD} \s)?
                       (?: #{SUBSECT_ABBR} \s #{UPPER_WORD} \s)?
                       (?: #{STIRPS_ABBR} \s #{UPPER_WORD}) ['"]?)/x
  SPECIES_TAXON     = /(#{PROV_RANK_PREFIX})?(['"]? #{UPPER_WORD} \s #{LOWER_WORD_OR_SP_NOV} ['"]?)/x
  # rubocop:enable Layout/LineLength

  GENUS_OR_UP_PAT = /^ #{GENUS_OR_UP_TAXON} (\s #{AUTHOR_START}.*)? $/x
  SUBGENUS_PAT    = /^ #{SUBGENUS_TAXON}    (\s #{AUTHOR_START}.*)? $/x
  SECTION_PAT     = /^ #{SECTION_TAXON}     (\s #{AUTHOR_START}.*)? $/x
  SUBSECTION_PAT  = /^ #{SUBSECTION_TAXON}  (\s #{AUTHOR_START}.*)? $/x
  STIRPS_PAT      = /^ #{STIRPS_TAXON}      (\s #{AUTHOR_START}.*)? $/x
  SPECIES_PAT     = /^ #{SPECIES_TAXON}     (\s #{AUTHOR_START}.*)? $/x
  SUBSPECIES_PAT  = /^ (#{PROV_RANK_PREFIX})?(['"]? #{BINOMIAL}
                       (?: \s #{SSP_ABBR} \s #{LOWER_WORD}) ['"]?)
                       (\s #{AUTHOR_START}.*)?
                   $/x
  VARIETY_PAT     = /^ (#{PROV_RANK_PREFIX})?(['"]? #{BINOMIAL}
                       (?: \s #{SSP_ABBR} \s #{LOWER_WORD})?
                       (?: \s #{VAR_ABBR} \s #{LOWER_WORD}) ['"]?)
                       (\s #{AUTHOR_START}.*)?
                   $/x
  FORM_PAT        = /^ (#{PROV_RANK_PREFIX})?(['"]? #{BINOMIAL}
                         (?: \s #{SSP_ABBR} \s #{LOWER_WORD})?
                         (?: \s #{VAR_ABBR} \s #{LOWER_WORD})?
                         (?: \s #{F_ABBR} \s #{LOWER_WORD}) ['"]?)
                       (\s #{AUTHOR_START}.*)?
                   $/x

  GROUP_PAT       = /^(?<taxon>
                        #{GENUS_OR_UP_TAXON} |
                        #{SUBGENUS_TAXON}    |
                        #{SECTION_TAXON}     |
                        #{SUBSECTION_TAXON}  |
                        #{STIRPS_TAXON}      |
                        #{SPECIES_TAXON}     |
                        (?: (?: #{PROV_RANK_PREFIX})?['"]? #{UPPER_WORD}
                          (?: \s #{LOWER_WORD}
                            (?: \s #{SSP_ABBR} \s #{LOWER_WORD})?
                            (?: \s #{VAR_ABBR} \s #{LOWER_WORD})?
                            (?: \s #{F_ABBR}   \s #{LOWER_WORD})?
                          )? ['"]?
                        )
                      )
                      (
                        ( # group, optionally followed by author
                          \s #{GROUP_ABBR} (\s (#{AUTHOR_START}.*))?
                        )
                        | # or
                        ( # author followed by group
                          ( \s (#{AUTHOR_START}.*)) \s #{GROUP_ABBR}
                        )
                      )
                    $/x

  # group or clade part of name, with
  # <group_wd> capture group capturing the stripped group or clade abbr
  GROUP_CHUNK     = /\s (?<group_wd>#{GROUP_ABBR}) \b/x

  # matches to ranks that are included in the name proper
  RANK_START_MATCHER = /^(f|sect|stirps|subg|subsect|v|sp|ssp|subsp|s)/i

  # convert rank start_match to standard form of rank
  # subspecies is not included because it's the catchall default
  STANDARD_SECONDARY_RANKS = {
    f: "f.",
    sect: "sect.",
    section: "sect.",
    sp: "sp.",
    stirps: "stirps",
    subg: "subg.",
    subsect: "subsect.",
    v: "var.",
    s: "subsp.",
    ssp: "subsp.",
    subsp: "subsp."
  }.freeze

  class RankMessedUp < ::StandardError
  end

  # Parse a name given no additional information. Returns a ParsedName instance.
  def parse_name(str, rank: "Genus", deprecated: false)
    str = clean_incoming_string(str)
    parse_group(str, deprecated) ||
      parse_subgenus(str, deprecated) ||
      parse_section(str, deprecated) ||
      parse_subsection(str, deprecated) ||
      parse_stirps(str, deprecated) ||
      parse_subspecies(str, deprecated) ||
      parse_variety(str, deprecated) ||
      parse_form(str, deprecated) ||
      parse_species(str, deprecated) ||
      parse_genus_or_up(str, deprecated, rank)
  end

  # Guess rank of +text_name+.
  def guess_rank(text_name, prov_rank = "")
    rank = prov_rank&.strip
    return PROV_RANKS[rank] if PROV_RANKS.include?(rank)

    TEXT_NAME_MATCHERS.find { |m| m.match?(text_name) }.rank
  end

  def parse_author(str)
    str = clean_incoming_string(str)
    results = [str, nil]
    if (match = AUTHOR_PAT.match(str))
      results = [match[1].strip, match[2].strip]
    end
    results
  end

  def parse_group(str, deprecated = false)
    return unless GROUP_PAT.match(str)

    result = parse_name(str_without_group(str),
                        rank: "Group", deprecated: deprecated)
    return nil unless result

    # Adjust the parsed name
    group_type = standardized_group_abbr(str)

    result.text_name += " #{group_type}"

    if result.author.present?
      # Add "clade" or "group" before author
      author = Regexp.escape(result.author)
      result.search_name.sub!(/(#{author})$/, "#{group_type} \\1")
      result.sort_name.sub!(/(#{author})$/, " #{group_type}  \\1")
      result.display_name.sub!(/(#{author})$/, "#{group_type} \\1")
    else
      # Append "group" at end
      result.search_name +=  " #{group_type}"
      result.sort_name +=    "   #{group_type}"
      result.display_name += " #{group_type}"
    end

    result.rank = "Group"
    result.parent_name ||= ""

    result
  end

  def str_without_group(str)
    str.sub(GROUP_CHUNK, "")
  end

  def standardized_group_abbr(str)
    word = group_wd(str.to_s.downcase)
    word.start_with?("g") ? "group" : word
  end

  # sripped group_abbr
  def group_wd(str)
    GROUP_CHUNK.match(str)[:group_wd]
  end

  def standardize_text_name(name, rank)
    result = name.tr('"', "'")
    result = "'#{result}'" if /[0-9]/.match?(result) && result[0] != "'"
    if result[0] == "'"
      prefix = PROV_RANKS.key(rank)
      result = "#{prefix} #{result}" if prefix
    end
    result.tr("ë", "e")
  end

  def parse_genus_or_up(str, deprecated = false, rank = "Genus")
    results = nil
    if (match = GENUS_OR_UP_PAT.match(str))
      prov_rank = match[1]
      name = match[2]
      author = match[3]
      unless Name.ranks_above_genus.include?(rank)
        rank = guess_rank(name,
                          prov_rank)
      end
      (name, author, rank) = fix_autonym(name, author, rank)
      author = standardize_author(author)
      author2 = author.blank? ? "" : " #{author}"
      text_name = standardize_text_name(name, rank)
      parent_name = if Name.ranks_below_genus.include?(rank)
                      name.sub(LAST_PART, "")
                    end
      display_name = format_autonym(text_name, author, rank, deprecated)
      results = ParsedName.new(
        text_name: text_name,
        search_name: text_name + author2,
        sort_name: format_sort_name(text_name, author),
        display_name: display_name,
        parent_name: parent_name,
        rank: rank,
        author: author
      )
    end
    results
  rescue RankMessedUp
    nil
  end

  def clean_prov_spaces(name)
    while (match = /('[^' ]+ [^']+')/.match(name))
      name.sub!(match[1], match[1].tr(" ", "-"))
    end
    name
  end

  def parse_below_genus(str, deprecated, rank, pattern)
    results = nil
    if (match = pattern.match(str))
      name = match[2].tr('"', "'")
      name = clean_prov_spaces(name)
      author = match[3].to_s
      name = standardize_sp_nov_variants(name) if rank == "Species"
      (name, author, rank) = fix_autonym(name, author, rank)
      name = standardize_name(name)
      author = standardize_author(author)
      author2 = author.blank? ? "" : " #{author}"
      text_name = name.tr("ë", "e")
      parent_name = name.sub(LAST_PART, "")
      display_name = format_autonym(name, author, rank, deprecated)
      results = ParsedName.new(
        text_name: text_name,
        search_name: text_name + author2,
        sort_name: format_sort_name(text_name, author),
        display_name: display_name,
        parent_name: parent_name,
        rank: rank,
        author: author
      )
    end
    results
  rescue RankMessedUp
    nil
  end

  def parse_subgenus(str, deprecated = false)
    parse_below_genus(str, deprecated, "Subgenus", SUBGENUS_PAT)
  end

  def parse_section(str, deprecated = false)
    parse_below_genus(str, deprecated, "Section", SECTION_PAT)
  end

  def parse_subsection(str, deprecated = false)
    parse_below_genus(str, deprecated, "Subsection", SUBSECTION_PAT)
  end

  def parse_stirps(str, deprecated = false)
    parse_below_genus(str, deprecated, "Stirps", STIRPS_PAT)
  end

  def parse_species(str, deprecated = false)
    parse_below_genus(str, deprecated, "Species", SPECIES_PAT)
  end

  def parse_subspecies(str, deprecated = false)
    parse_below_genus(str, deprecated, "Subspecies", SUBSPECIES_PAT)
  end

  def parse_variety(str, deprecated = false)
    parse_below_genus(str, deprecated, "Variety", VARIETY_PAT)
  end

  def parse_form(str, deprecated = false)
    parse_below_genus(str, deprecated, "Form", FORM_PAT)
  end

  def parse_rank_abbreviation(str)
    RANK_FROM_ABBREV_MATCHERS.find { |matcher| matcher.match?(str) }.rank
  end

  # Standardize various ways of writing sp. nov.  Convert to: Amanita sp. "T44"
  def standardize_sp_nov_variants(name)
    names = split_name(name)
    return name if names.length != 2

    names[1] = "'#{names[1]}'" if UNQUOTED_PROV.match?(names[1])
    names[1].sub!(/^'sp-/i, "sp. '")
    names[1].sub!(/^'/, "sp. '")
    names.join(" ").strip
  end

  def split_name(name)
    result = []
    words = name.split
    result.append(take_name(words)) while words.length.positive?
    result
  end

  def take_name(words)
    result = words.shift
    unless PROV_RANKS.include?(result) ||
           /^#{ANY_RANK_ABBR}$/o.match?(result.downcase)
      return result
    end

    result = result.downcase if ANY_RANK_ABBR.match?(result.downcase)
    "#{result} #{words.shift}"
  end

  # Fix common error: Amanita vaginatae Author var. vaginatae
  # Convert to: Amanita vaginatae var. vaginatae Author
  def fix_autonym(name, author, rank)
    last_word = name.split.last.gsub(/[()]/, "")
    if (match = author.to_s.match(
      /^(.*?)(( (#{ANY_SUBG_ABBR}|#{ANY_SSP_ABBR}) #{last_word})+)$/
    ))
      name = "#{name}#{match[2]}"
      author = match[1].strip
      words = match[2].split
      while words.any?
        next_rank = parse_rank_abbreviation(words.shift)
        words.shift
        make_sure_ranks_ordered_right!(rank, next_rank)
        rank = next_rank
      end
    end
    [name, author, rank]
  end

  def make_sure_ranks_ordered_right!(prev_rank, next_rank)
    if compare_ranks(prev_rank, next_rank) <= 0 ||
       Name.ranks_above_species.include?(prev_rank) &&
       Name.ranks_below_species.include?(next_rank)
      raise(RankMessedUp.new)
    end
  end

  def find_autonyms(names)
    return [] if names.empty?

    last_name = names.last
    nym = last_name.split[-1]
    (names.length - 1).downto(0) do |i|
      return i + 1 unless nym == names[i].split[-1]
    end
    0
  end

  # Format a name ranked below genus, moving the author to before the var.
  # in natural varieties such as
  # "__Acarospora nodulosa__ (Dufour) Hue var. __nodulosa__".
  def format_autonym(name, author, _rank, deprecated)
    return format_name(name, deprecated) if author.blank?

    names = split_name(name)
    index = find_autonyms(names)
    [
      format_name(names[..index].join(" "), deprecated),
      author,
      format_name(names[(index + 1)..].join(" ").strip, deprecated)
    ].join(" ").strip
  end

  def standardize_name(name)
    subnames = split_name(name)
    subnames[0] = "Gen. #{subnames[0]}" if subnames[0][0] == "'"
    1.upto(subnames.length - 1) do |i|
      subnames[i] = standardize_subname(subnames[i])
    end
    subnames.join(" ").strip
  end

  def standardize_subname(subname)
    if /^#{ANY_RANK_ABBR} /o.match?(subname)
      match = /^([^\.\s]+)\.? (.+)$/.match(subname)
      raise(RankMessedUp.new) unless match

      rank = standardize_subrank(match[1])
      term = match[2]
      term = "'#{term}'" if rank == "sp." && term[0] != "'"
      return "#{rank} #{term}" if match
    end
    subname
  end

  def standardize_subrank(rank)
    match = RANK_START_MATCHER.match(rank)
    return rank unless match

    STANDARD_SECONDARY_RANKS[match[1].downcase.to_sym]
  end

  def standardize_author(str)
    str = str.to_s.
          sub(/^ ?#{AUCT_ABBR}/o,  "auct. ").
          sub(/^ ?#{INED_ABBR}/o,  "ined. ").
          sub(/^ ?#{NOM_ABBR}/o,   "nom. ").
          sub(/^ ?#{COMB_ABBR}/o,  "comb. ").
          sub(/^ ?#{SENSU_ABBR}/o, "sensu ").
          # Having fixed comb. & nom., standardize their suffixes
          sub(/(?<=comb. |nom. ) ?#{NOV_ABBR}/o,  "nov. ").
          sub(/(?<=comb. |nom. ) ?#{PROV_ABBR}/o, "prov. ").
          strip_squeeze
    squeeze_author(str)
  end

  # Squeeze "A. H. Smith" into "A.H. Smith".
  def squeeze_author(str)
    str.gsub(/([A-Z]\.) (?=[A-Z]\.)/, '\\1')
  end

  # Add italics and boldface markup to a standardized name (without author).
  def format_name(str, deprecated = false)
    boldness = deprecated ? "" : "**"
    raw_names = split_name(str)
    result_names = []
    raw_names.each do |name|
      if name.index(" ")
        name.sub!(" ", " #{boldness}__")
      else
        name = "#{boldness}__#{name}"
      end
      result_names.append("#{name}__#{boldness}")
    end
    result_names.join(" ")
  end

  def clean_incoming_string(str)
    str = str.unicode_normalize(:nfc) if str.encoding == Encoding::UTF_8
    str.to_s.
      gsub(/“|”/, '"'). # let RedCloth format quotes
      gsub(/‘|’/, "'").
      delete("\u2028"). # Unicode RLE that we see occasionally as line separator
      gsub(/\s+/, " ").
      strip_squeeze
  end

  # Adjust +search_name+ string to collate correctly. Pass in +search_name+.
  def format_sort_name(name, author)
    str = format_name(name, :deprecated).
          sub(/_+$/, " "). # put genus at the top
          gsub(/_+/, "").
          sub(/ sp. /, " "). # ignore sp.
          sub(/^[A-Z][a-z]+\. /, ""). # ignore leading ranks like Gen.
          gsub(/ '([^']*')/, &:downcase). # downcase prov epithets
          delete("'"). # Now ignore quotes
          sub(" subg. ", "  {1subg.  ").
          sub(" sect. ",    "  {2sect.  ").
          sub(" subsect. ", "  {3subsect.  ").
          sub(" stirps ",   "  {4stirps  ").
          sub(" subsp. ",   "  {5subsp.  ").
          sub(" var. ",     "  {6var.  ").
          sub(" f. ", "  {7f.  ").
          strip.
          sub(/(^\S+)aceae$/,        '\1!7').
          sub(/(^\S+)ineae$/,        '\1!6').
          sub(/(^\S+)ales$/,         '\1!5').
          sub(/(^\S+?)o?mycetidae$/, '\1!4').
          sub(/(^\S+?)o?mycetes$/,   '\1!3').
          sub(/(^\S+?)o?mycotina$/,  '\1!2').
          sub(/(^\S+?)o?mycota$/,    '\1!1')

    # put autonyms at the top
    1 while str.sub!(/(^| )([A-Za-z-]+) (.*) \2( |$)/, '\1\2 \3 !\2\4')

    if author.present?
      # Disable cop because interpolation causes test failures
      str += "  " + author. # rubocop:disable Style/StringConcatenation
             delete('"'). # Ignore quotes in author
             gsub(/[Đđ]/, "d"). # mysql isn't collating these right
             gsub(/[Øø]/, "O").
             strip
    end
    str
  end
end
