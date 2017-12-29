class Name < AbstractModel
  SUBG_ABBR    = / subgenus | subg\.? /xi
  SECT_ABBR    = / section | sect\.? /xi
  SUBSECT_ABBR = / subsection | subsect\.? /xi
  STIRPS_ABBR  = / stirps /xi
  SP_ABBR      = / species | sp\.? /xi
  SSP_ABBR     = / subspecies | subsp\.? | ssp\.? | s\.? /xi
  VAR_ABBR     = / variety | var\.? | v\.? /xi
  F_ABBR       = / forma | form\.? | fo\.? | f\.? /xi
  GROUP_ABBR   = / group | gr\.? | gp\.? | clade | complex /xi
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

  UPPER_WORD = / [A-Z][a-zë\-]*[a-zë] | "[A-Z][a-zë\-\.]*[a-zë]" /x
  LOWER_WORD = / (?!sensu\b) [a-z][a-zë\-]*[a-zë] | "[a-z][\wë\-\.]*[\wë]" /x
  BINOMIAL   = / #{UPPER_WORD} \s #{LOWER_WORD} /x
  LOWER_WORD_OR_SP_NOV = / (?! sp\s|sp$|species) #{LOWER_WORD} |
                           sp\.\s\S*\d\S* /x

  # Matches the last epithet in a (standardized) name,
  # including preceding abbreviation if there is one.
  LAST_PART = / (?: \s[a-z]+\.? )? \s \S+ $/x

  AUTHOR_START = / #{ANY_AUTHOR_ABBR} | van\s | de\s | [
                   A-ZÀÁÂÃÄÅÆÇĐÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞČŚŠ\(] | "[^a-z\s] /x

  # AUTHOR_PAT is separate from, and can't include GENUS_OR_UP_TAXON, etc.
  #   AUTHOR_PAT ensures "sp", "ssp", etc., aren't included in author.
  #   AUTHOR_PAT removes the author first thing.
  # Then the other parsers have a much easier job.
  AUTHOR_PAT =
    /^
      ( "?
        #{UPPER_WORD}
        (?:
            # >= 1 of (rank Epithet)
            \s     #{ANY_SUBG_ABBR} \s #{UPPER_WORD}
            (?: \s #{ANY_SUBG_ABBR} \s #{UPPER_WORD} )* "?
          |
            \s (?! #{AUTHOR_START} | #{ANY_SUBG_ABBR} ) #{LOWER_WORD}
            (?: \s #{ANY_SSP_ABBR} \s #{LOWER_WORD} )* "?
          |
            "? \s #{SP_ABBR}
        )?
      )
      ( \s (?! #{ANY_NAME_ABBR} \s ) #{AUTHOR_START}.* )
    $/x

  # Taxa without authors (for use by GROUP PAT)
  # rubocop:disable Metrics/LineLength
  GENUS_OR_UP_TAXON = /("? (?:Fossil-)? #{UPPER_WORD} "?) (?: \s #{SP_ABBR} )?/x
  SUBGENUS_TAXON    = /("? #{UPPER_WORD} \s (?: #{SUBG_ABBR} \s #{UPPER_WORD}) "?)/x
  SECTION_TAXON     = /("? #{UPPER_WORD} \s (?: #{SUBG_ABBR} \s #{UPPER_WORD} \s)?
                       (?: #{SECT_ABBR} \s #{UPPER_WORD}) "?)/x
  SUBSECTION_TAXON  = /("? #{UPPER_WORD} \s (?: #{SUBG_ABBR} \s #{UPPER_WORD} \s)?
                       (?: #{SECT_ABBR} \s #{UPPER_WORD} \s)?
                       (?: #{SUBSECT_ABBR} \s #{UPPER_WORD}) "?)/x
  STIRPS_TAXON      = /("? #{UPPER_WORD} \s (?: #{SUBG_ABBR} \s #{UPPER_WORD} \s)?
                       (?: #{SECT_ABBR} \s #{UPPER_WORD} \s)?
                       (?: #{SUBSECT_ABBR} \s #{UPPER_WORD} \s)?
                       (?: #{STIRPS_ABBR} \s #{UPPER_WORD}) "?)/x
  SPECIES_TAXON     = /("? #{UPPER_WORD} \s #{LOWER_WORD_OR_SP_NOV} "?)/x
  # rubocop:enable Metrics/LineLength

  GENUS_OR_UP_PAT = /^ #{GENUS_OR_UP_TAXON} (\s #{AUTHOR_START}.*)? $/x
  SUBGENUS_PAT    = /^ #{SUBGENUS_TAXON}    (\s #{AUTHOR_START}.*)? $/x
  SECTION_PAT     = /^ #{SECTION_TAXON}     (\s #{AUTHOR_START}.*)? $/x
  SUBSECTION_PAT  = /^ #{SUBSECTION_TAXON}  (\s #{AUTHOR_START}.*)? $/x
  STIRPS_PAT      = /^ #{STIRPS_TAXON}      (\s #{AUTHOR_START}.*)? $/x
  SPECIES_PAT     = /^ #{SPECIES_TAXON}     (\s #{AUTHOR_START}.*)? $/x
  SUBSPECIES_PAT  = /^ ("? #{BINOMIAL} (?: \s #{SSP_ABBR} \s #{LOWER_WORD}) "?)
                       (\s #{AUTHOR_START}.*)?
                   $/x
  VARIETY_PAT     = /^ ("? #{BINOMIAL} (?: \s #{SSP_ABBR} \s #{LOWER_WORD})?
                         (?: \s #{VAR_ABBR} \s #{LOWER_WORD}) "?)
                       (\s #{AUTHOR_START}.*)?
                   $/x
  FORM_PAT        = /^ ("? #{BINOMIAL} (?: \s #{SSP_ABBR} \s #{LOWER_WORD})?
                         (?: \s #{VAR_ABBR} \s #{LOWER_WORD})?
                         (?: \s #{F_ABBR} \s #{LOWER_WORD}) "?)
                       (\s #{AUTHOR_START}.*)?
                   $/x

  GROUP_PAT       = /^(?<taxon>
                        #{GENUS_OR_UP_TAXON} |
                        #{SUBGENUS_TAXON}    |
                        #{SECTION_TAXON}     |
                        #{SUBSECTION_TAXON}  |
                        #{STIRPS_TAXON}      |
                        #{SPECIES_TAXON}     |
                        (?: "? #{UPPER_WORD} # infra-species taxa
                          (?: \s #{LOWER_WORD}
                            (?: \s #{SSP_ABBR} \s #{LOWER_WORD})?
                            (?: \s #{VAR_ABBR} \s #{LOWER_WORD})?
                            (?: \s #{F_ABBR}   \s #{LOWER_WORD})?
                          )? "?
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

  # parsing a string to a Name
  class ParsedName
    attr_accessor :text_name, :search_name, :sort_name, :display_name
    attr_accessor :rank, :author, :parent_name

    def initialize(params)
      @text_name = params[:text_name]
      @search_name = params[:search_name]
      @sort_name = params[:sort_name]
      @display_name = params[:display_name]
      @parent_name = params[:parent_name]
      @rank = params[:rank]
      @author = params[:author]
    end

    def real_text_name
      Name.display_to_real_text(self)
    end

    def real_search_name
      Name.display_to_real_search(self)
    end

    # Values required to create/modify attributes of Name instance.
    def params
      {
        text_name: @text_name,
        search_name: @search_name,
        sort_name: @sort_name,
        display_name: @display_name,
        author: @author,
        rank: @rank
      }
    end

    def inspect
      params.merge(parent_name: @parent_name).inspect
    end
  end

  # Parse a name given no additional information. Returns a ParsedName instance.
  def self.parse_name(str, rank: :Genus, deprecated: false)
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
  def self.guess_rank(text_name)
    text_name.match(/ (group|clade|complex)$/) ? :Group :
    text_name.include?(" f. ")         ? :Form       :
    text_name.include?(" var. ")       ? :Variety    :
    text_name.include?(" subsp. ")     ? :Subspecies :
    text_name.include?(" stirps ")     ? :Stirps     :
    text_name.include?(" subsect. ")   ? :Subsection :
    text_name.include?(" sect. ")      ? :Section    :
    text_name.include?(" subgenus ")   ? :Subgenus   :
    text_name.include?(" ")            ? :Species    :
    text_name.match(/^\S+aceae$/)      ? :Family     :
    text_name.match(/^\S+ineae$/)      ? :Family     : # :Suborder
    text_name.match(/^\S+ales$/)       ? :Order      :
    text_name.match(/^\S+mycetidae$/)  ? :Order      : # :Subclass
    text_name.match(/^\S+mycetes$/)    ? :Class      :
    text_name.match(/^\S+mycotina$/)   ? :Class      : # :Subphylum
    text_name.match(/^\S+mycota$/)     ? :Phylum     :
    text_name.match(/^Fossil-/)        ? :Phylum     :
                                         :Genus
  end

  def self.parse_author(str)
    str = clean_incoming_string(str)
    results = [str, nil]
    if (match = AUTHOR_PAT.match(str))
      results = [match[1].strip, match[2].strip]
    end
    results
  end

  def self.parse_group(str, deprecated = false)
    return unless (match = GROUP_PAT.match(str))

    result = parse_name(str_without_group(str),
                        rank: :Group, deprecated: deprecated)
    return nil unless result

    # Adjust the parsed name
    group_type = standardized_group_abbr(str)

    result.text_name += " #{group_type}"

    if result.author.present?
      # Add "clade" or "group" before author
      author = Regexp.escape(result.author)
      result.search_name.sub!( /(#{author})$/, "#{group_type} \\1")
      result.sort_name.sub!(   /(#{author})$/, " #{group_type}  \\1")
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

  def self.str_without_group(str)
    str.sub(GROUP_CHUNK, "")
  end

  def self.standardized_group_abbr(str)
    word = group_wd(str.to_s.downcase)
    word =~ /^g/ ? "group" : word
  end

  # sripped group_abbr
  def self.group_wd(str)
    (GROUP_CHUNK.match(str))[:group_wd]
  end

  def self.parse_genus_or_up(str, deprecated = false, rank = :Genus)
    results = nil
    if (match = GENUS_OR_UP_PAT.match(str))
      name = match[1]
      author = match[2]
      rank = guess_rank(name) unless Name.ranks_above_genus.include?(rank)
      (name, author, rank) = fix_autonym(name, author, rank)
      author = standardize_author(author)
      author2 = author.blank? ? "" : " " + author
      text_name = name.tr("ë", "e")
      parent_name = Name.ranks_below_genus.include?(rank) ?
                      name.sub(LAST_PART, "") : nil
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
    return nil
  end

  def self.parse_below_genus(str, deprecated, rank, pattern)
    results = nil
    if match = pattern.match(str)
      name = match[1]
      author = match[2].to_s
      name = standardize_sp_nov_variants(name) if rank == :Species
      (name, author, rank) = fix_autonym(name, author, rank)
      name = standardize_name(name)
      author = standardize_author(author)
      author2 = author.blank? ? "" : " " + author
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
    return nil
  end

  def self.parse_subgenus(str, deprecated = false)
    parse_below_genus(str, deprecated, :Subgenus, SUBGENUS_PAT)
  end

  def self.parse_section(str, deprecated = false)
    parse_below_genus(str, deprecated, :Section, SECTION_PAT)
  end

  def self.parse_subsection(str, deprecated = false)
    parse_below_genus(str, deprecated, :Subsection, SUBSECTION_PAT)
  end

  def self.parse_stirps(str, deprecated = false)
    parse_below_genus(str, deprecated, :Stirps, STIRPS_PAT)
  end

  def self.parse_species(str, deprecated = false)
    parse_below_genus(str, deprecated, :Species, SPECIES_PAT)
  end

  def self.parse_subspecies(str, deprecated = false)
    parse_below_genus(str, deprecated, :Subspecies, SUBSPECIES_PAT)
  end

  def self.parse_variety(str, deprecated = false)
    parse_below_genus(str, deprecated, :Variety, VARIETY_PAT)
  end

  def self.parse_form(str, deprecated = false)
    parse_below_genus(str, deprecated, :Form, FORM_PAT)
  end

  def self.parse_rank_abbreviation(str)
    str.match(SUBG_ABBR) ? :Subgenus : str.match(SECT_ABBR) ? :Section :
    str.match(SUBSECT_ABBR) ? :Subsection :
    str.match(STIRPS_ABBR) ? :Stirps :
    str.match(SSP_ABBR) ? :Subspecies :
    str.match(VAR_ABBR) ? :Variety : str.match(F_ABBR) ? :Form : nil
  end

  # Standardize various ways of writing sp. nov.  Convert to: Amanita "sp-T44"
  def self.standardize_sp_nov_variants(name)
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
  def self.fix_autonym(name, author, rank)
    last_word = name.split(" ").last.gsub(/[()]/, "")
    if match = author.to_s.match(/^(.*?)(( (#{ANY_SUBG_ABBR}|#{ANY_SSP_ABBR}) #{last_word})+)$/)
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

  class RankMessedUp < ::StandardError
  end

  def self.make_sure_ranks_ordered_right!(prev_rank, next_rank)
    if compare_ranks(prev_rank, next_rank) <= 0 ||
       Name.ranks_above_species.include?(prev_rank) &&
       Name.ranks_below_species.include?(next_rank)
      raise RankMessedUp.new
    end
  end

  # Format a name ranked below genus, moving the author to before the var.
  # in natural varieties such as
  # "__Acarospora nodulosa__ (Dufour) Hue var. __nodulosa__".
  def self.format_autonym(name, author, _rank, deprecated)
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

  def self.standardize_name(str)
    words = str.split(" ")
    # every other word, starting next-from-last, is an abbreviation
    i = words.length - 2
    while i > 0
      if words[i].match(/^f/i)
        words[i] = "f."
      elsif words[i].match(/^v/i)
        words[i] = "var."
      elsif words[i].match(/^sect/i)
        words[i] = "sect."
      elsif words[i].match(/^stirps/i)
        words[i] = "stirps"
      elsif words[i].match(/^subg/i)
        words[i] = "subgenus"
      elsif words[i].match(/^subsect/i)
        words[i] = "subsect."
      else
        words[i] = "subsp."
      end
      i -= 2
    end
    words.join(" ")
  end

  def self.standardize_author(str)
    str = str.to_s.
          sub(/^ ?#{AUCT_ABBR}/,  "auct. ").
          sub(/^ ?#{INED_ABBR}/,  "ined. ").
          sub(/^ ?#{NOM_ABBR}/,   "nom. ").
          sub(/^ ?#{COMB_ABBR}/,  "comb. ").
          sub(/^ ?#{SENSU_ABBR}/, "sensu ").
          # Having fixed comb. & nom., standardize their suffixes
          sub(/(?<=comb. |nom. ) ?#{NOV_ABBR}/,  "nov. ").
          sub(/(?<=comb. |nom. ) ?#{PROV_ABBR}/, "prov. ").
          strip_squeeze
    squeeze_author(str)
  end

  # Squeeze "A. H. Smith" into "A.H. Smith".
  def self.squeeze_author(str)
    str.gsub(/([A-Z]\.) (?=[A-Z]\.)/, '\\1')
  end

  # Add italics and boldface markup to a standardized name (without author).
  def self.format_name(str, deprecated = false)
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

  def self.clean_incoming_string(str)
    str.to_s.
      gsub(/“|”/, '"'). # let RedCloth format quotes
      gsub(/‘|’/, "'").
      gsub(/\u2028/, ""). # line separator that we see occasionally
      strip_squeeze
  end

  # Adjust +search_name+ string to collate correctly. Pass in +search_name+.
  def self.format_sort_name(name, author)
    str = format_name(name, :deprecated).
          sub(/^_+/, "").
          gsub(/_+/, " "). # put genus at the top
          sub(/ "(sp[\-\.])/, ' {\1'). # put "sp-1" at end
          gsub(/"([^"]*")/, '\1'). # collate "baccata" with baccata
          sub(" subgenus ", " {1subgenus ").
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
    1 while str.sub!(/(^| )([A-Za-z\-]+) (.*) \2( |$)/, '\1\2 \3 !\2\4') # put autonyms at the top

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
