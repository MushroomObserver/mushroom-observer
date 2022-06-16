# frozen_string_literal: true

# NOTE: Use `Name extend Parse`: these are all class methods
module Name::Parse
  class RankMessedUp < ::StandardError
  end

  # Parse a name given no additional information. Returns a ParsedName instance.
  def parse_name(str, rank: :Genus, deprecated: false)
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
  def guess_rank(text_name)
    Name::TEXT_NAME_MATCHERS.find { |matcher| matcher.match?(text_name) }.rank
  end

  def parse_author(str)
    str = clean_incoming_string(str)
    results = [str, nil]
    if (match = Name::AUTHOR_PAT.match(str))
      results = [match[1].strip, match[2].strip]
    end
    results
  end

  def parse_group(str, deprecated = false)
    return unless Name::GROUP_PAT.match(str)

    result = parse_name(str_without_group(str),
                        rank: :Group, deprecated: deprecated)
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

    result.rank = :Group
    result.parent_name ||= ""

    result
  end

  def str_without_group(str)
    str.sub(Name::GROUP_CHUNK, "")
  end

  def standardized_group_abbr(str)
    word = group_wd(str.to_s.downcase)
    word.start_with?("g") ? "group" : word
  end

  # sripped group_abbr
  def group_wd(str)
    Name::GROUP_CHUNK.match(str)[:group_wd]
  end

  def parse_genus_or_up(str, deprecated = false, rank = :Genus)
    results = nil
    if (match = Name::GENUS_OR_UP_PAT.match(str))
      name = match[1]
      author = match[2]
      rank = guess_rank(name) unless Name.ranks_above_genus.include?(rank)
      (name, author, rank) = fix_autonym(name, author, rank)
      author = standardize_author(author)
      author2 = author.blank? ? "" : " #{author}"
      text_name = name.tr("ë", "e")
      parent_name = if Name.ranks_below_genus.include?(rank)
                      name.sub(Name::LAST_PART, "")
                    end
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

  def parse_below_genus(str, deprecated, rank, pattern)
    results = nil
    if (match = pattern.match(str))
      name = match[1]
      author = match[2].to_s
      name = standardize_sp_nov_variants(name) if rank == :Species
      (name, author, rank) = fix_autonym(name, author, rank)
      name = standardize_name(name)
      author = standardize_author(author)
      author2 = author.blank? ? "" : " #{author}"
      text_name = name.tr("ë", "e")
      parent_name = name.sub(Name::LAST_PART, "")
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
    parse_below_genus(str, deprecated, :Subgenus, Name::SUBGENUS_PAT)
  end

  def parse_section(str, deprecated = false)
    parse_below_genus(str, deprecated, :Section, Name::SECTION_PAT)
  end

  def parse_subsection(str, deprecated = false)
    parse_below_genus(str, deprecated, :Subsection, Name::SUBSECTION_PAT)
  end

  def parse_stirps(str, deprecated = false)
    parse_below_genus(str, deprecated, :Stirps, Name::STIRPS_PAT)
  end

  def parse_species(str, deprecated = false)
    parse_below_genus(str, deprecated, :Species, Name::SPECIES_PAT)
  end

  def parse_subspecies(str, deprecated = false)
    parse_below_genus(str, deprecated, :Subspecies, Name::SUBSPECIES_PAT)
  end

  def parse_variety(str, deprecated = false)
    parse_below_genus(str, deprecated, :Variety, Name::VARIETY_PAT)
  end

  def parse_form(str, deprecated = false)
    parse_below_genus(str, deprecated, :Form, Name::FORM_PAT)
  end

  def parse_rank_abbreviation(str)
    Name::RANK_FROM_ABBREV_MATCHERS.find { |matcher| matcher.match?(str) }.rank
  end

  # Standardize various ways of writing sp. nov.  Convert to: Amanita "sp-T44"
  def standardize_sp_nov_variants(name)
    words = name.split(" ")
    if words.length > 2
      genus = words[0]
      epithet = words[2]
      epithet.sub!(/^"(.*)"$/, '\1')
      name = "#{genus} \"sp-#{epithet}\""
    else
      name.sub!(/ "sp\./i, ' "sp-')
    end
    name
  end

  # Fix common error: Amanita vaginatae Author var. vaginatae
  # Convert to: Amanita vaginatae var. vaginatae Author
  def fix_autonym(name, author, rank)
    last_word = name.split(" ").last.gsub(/[()]/, "")
    if (match = author.to_s.match(
      /^(.*?)(( (#{Name::ANY_SUBG_ABBR}|#{Name::ANY_SSP_ABBR}) #{last_word})+)$/
    ))
      name = "#{name}#{match[2]}"
      author = match[1].strip
      words = match[2].split(" ")
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

  # Format a name ranked below genus, moving the author to before the var.
  # in natural varieties such as
  # "__Acarospora nodulosa__ (Dufour) Hue var. __nodulosa__".
  def format_autonym(name, author, _rank, deprecated)
    words = name.split(" ")
    if author.blank?
      format_name(name, deprecated)
    elsif words[-7] == words[-1]
      [
        format_name(words[0..-7].join(" "), deprecated),
        author,
        words[-6],
        format_name(words[-5], deprecated),
        words[-4],
        format_name(words[-3], deprecated),
        words[-2],
        format_name(words[-1], deprecated)
      ].join(" ")
    elsif words[-5] == words[-1]
      [
        format_name(words[0..-5].join(" "), deprecated),
        author,
        words[-4],
        format_name(words[-3], deprecated),
        words[-2],
        format_name(words[-1], deprecated)
      ].join(" ")
    elsif words[-3] == words[-1]
      [
        format_name(words[0..-3].join(" "), deprecated),
        author,
        words[-2],
        format_name(words[-1], deprecated)
      ].join(" ")
    else
      format_name(name, deprecated) + " " + author
    end
  end

  def standardize_name(str)
    words = str.split(" ")
    # every other word, starting next-from-last, is an abbreviation
    i = words.length - 2
    while i.positive?
      words[i] = if (match_start_of_rank =
                       Name::RANK_START_MATCHER.match(words[i]))
                   start_of_rank = match_start_of_rank[0]
                   Name::STANDARD_SECONDARY_RANKS[start_of_rank.downcase.to_sym]
                 else
                   "subsp."
                 end
      i -= 2
    end
    words.join(" ")
  end

  def standardize_author(str)
    str = str.to_s.
          sub(/^ ?#{Name::AUCT_ABBR}/,  "auct. ").
          sub(/^ ?#{Name::INED_ABBR}/,  "ined. ").
          sub(/^ ?#{Name::NOM_ABBR}/,   "nom. ").
          sub(/^ ?#{Name::COMB_ABBR}/,  "comb. ").
          sub(/^ ?#{Name::SENSU_ABBR}/, "sensu ").
          # Having fixed comb. & nom., standardize their suffixes
          sub(/(?<=comb. |nom. ) ?#{Name::NOV_ABBR}/,  "nov. ").
          sub(/(?<=comb. |nom. ) ?#{Name::PROV_ABBR}/, "prov. ").
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
    words = str.split(" ")
    if words.length.even?
      genus = words.shift
      words[0] = genus + " " + words[0]
    end
    i = words.length - 1
    while i >= 0
      words[i] = "#{boldness}__#{words[i]}__#{boldness}"
      i -= 2
    end

    words.join(" ")
  end

  def clean_incoming_string(str)
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
          sub(/^_+/, "").
          gsub(/_+/, " "). # put genus at the top
          sub(/ "(sp[\-.])/, ' {\1'). # put "sp-1" at end
          gsub(/"([^"]*")/, '\1'). # collate "baccata" with baccata
          sub(" subg. ", " {1subg. ").
          sub(" sect. ",    " {2sect. ").
          sub(" subsect. ", " {3subsect. ").
          sub(" stirps ",   " {4stirps ").
          sub(" subsp. ",   " {5subsp. ").
          sub(" var. ",     " {6var. ").
          sub(" f. ", " {7f. ").
          strip.
          sub(/(^\S+)aceae$/,        '\1!7').
          sub(/(^\S+)ineae$/,        '\1!6').
          sub(/(^\S+)ales$/,         '\1!5').
          sub(/(^\S+?)o?mycetidae$/, '\1!4').
          sub(/(^\S+?)o?mycetes$/,   '\1!3').
          sub(/(^\S+?)o?mycotina$/,  '\1!2').
          sub(/(^\S+?)o?mycota$/,    '\1!1')

    # put autonyms at the top
    1 while str.sub!(/(^| )([A-Za-z\-]+) (.*) \2( |$)/, '\1\2 \3 !\2\4')

    if author.present?
      str += "  " + author.
             gsub(/"([^"]*")/, '\1'). # collate "baccata" with baccata
             gsub(/[Đđ]/, "d"). # mysql isn't collating these right
             gsub(/[Øø]/, "O").
             strip
    end
    str
  end
end
