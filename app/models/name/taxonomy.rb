# frozen_string_literal: true

module Name::Taxonomy
  # When we `include` a module, the way to add class methods is like this:
  def self.included(base)
    base.extend(ClassMethods)
  end

  def at_or_below_genus?
    rank == "Genus" || below_genus?
  end

  def above_genus?
    Name.ranks_above_genus.include?(rank)
  end

  def below_genus?
    Name.ranks_below_genus.include?(rank) ||
      rank == "Group" && text_name.include?(" ")
  end

  def between_genus_and_species?
    below_genus? && !at_or_below_species?
  end

  def at_or_below_species?
    (rank == "Species") || Name.ranks_below_species.include?(rank)
  end

  def rank_index(rank)
    Name.all_ranks.index(rank)
  end

  def rank_translated
    Name.translate_rank(rank)
  end

  def has_eol_data?
    if ok_for_export && !deprecated && MO.eol_ranks_for_export.member?(rank)
      observations.each do |o|
        next unless o.vote_cache && o.vote_cache >= MO.eol_min_observation_vote

        o.images.each do |i|
          if i.ok_for_export && i.vote_cache &&
             i.vote_cache >= MO.eol_min_image_vote
            return true
          end
        end
      end
      descriptions.each do |d|
        return true if d.review_status == "vetted" &&
                       d.ok_for_export && d.public
      end
    end
    false
  end

  # ----------------------------------------------------------------------------

  # Is the Name (potentially) registrable in a fungal nomenclature repository?
  # This and #unregistrable are used in the views to determine whether
  # to display the ICN identifier, links to nomenclature records or searches
  def registrable?
    # Almost all Names in MO are potentially registrable, so use a blacklist
    # instead of a whitelist
    !unregistrable?
  end

  # Is name definitely in a fungal nomenclature repository?
  # (A heuristic that works for almost all cases)
  def unregistrable?
    rank == "Group" ||
      rank == "Domain" ||
      unpublished? ||
      # name includes quote marks, but limit this to below Order in order to
      # account for things like "Discomycetes", which is registered & quoted
      /"/ =~ text_name && rank >= "Class" ||
      # Use kingdom: Protozoa as a rough proxy for slime molds
      # Slime molds, which are Protozoa, are in fungal nomenclature registries.
      # But most Protozoa are not slime molds and there's no efficient way
      # for MO to tell the difference. So err on the side of registrability.
      kingdom.present? && /(Fungi|Protozoa)/ !~ kingdom
  end

  # Name for which it makes sense to have links to search pages in fungal
  # databases,though the name might be unregistrable. Ex: Boletus edulis group
  def searchable_in_registry?
    # Use blacklist instead of whitelist; almost all MO names are searchable
    !unsearchable_in_registry?
  end

  def unsearchable_in_registry?
    kingdom.present? && /(Fungi|Protozoa)/ !~ kingdom ||
      rank == "Domain" ||
      /\bcrypt temp\b/i =~ author&.delete(".")
  end

  ################

  private

  # Not published in any sense, or not intended as an ICN publication of a name.
  def unpublished?
    /\b(nom prov|comb prov|sensu lato|ined)\b/i =~ author&.delete(".")
  end

  # Kingdom as a string, e.g., "Fungi", or nil if no Kingdom
  def kingdom
    return text_name if rank == "Kingdom"

    parse_classification.find { |rank| rank.first == "Kingdom" }&.last
  end

  public

  # ----------------------------------------------------------------------------

  def homonyms
    Name.where(text_name: text_name).where.not(id: id)
  end

  # Returns an Array of all of this Name's ancestors, starting with its
  # immediate parent, running back to Eukarya.  It ignores misspellings.  It
  # chooses at random if there are more than one accepted parent taxa at a
  # given level.  (See comments for +parents+.)
  #
  #    child = Name.find_by_text_name('Letharia vulpina')
  #    child.all_parents.each do |parent|
  #      puts parent.text_name
  #    end
  #
  #    # Produces:
  #    Letharia
  #    Parmeliaceae
  #    Lecanorales
  #    Ascomycotina
  #    Ascomycota
  #    Fungi
  #    Eukarya
  #
  def all_parents(add_self: false, add_lichen: false, includes: [])
    parents(all: true, add_self: add_self, add_lichen: add_lichen,
            includes: includes)
  end

  # Returns an Array of all Name's under this one.  Ignores misspellings, but
  # includes deprecated Name's.  *NOTE*: This can be a _huge_ array!
  #
  #   parent = Name.find_by_text_name('Letharia')
  #   parent.all_children.each do |child|
  #     puts child.text_name
  #   end
  #
  #   # Produces:
  #   'Letharia californica'
  #   'Letharia columbiana'
  #   'Letharia lupina'
  #   'Letharia vulpina'
  #   'Letharia vulpina f. californica'
  #
  def all_children
    children(all: true)
  end

  # Returns the Name of the genus above this taxon.  If there are multiple
  # matching genera, it prefers accepted ones that are not "sensu xxx".
  # Beyond that it just chooses the first one arbitrarily.
  def accepted_genus
    @accepted_genus ||=
      begin
        accepted = approved_name
        if accepted.text_name.include?(" ")
          genus_name = accepted.text_name.split(" ", 2).first
          genera     = Name.with_correct_spelling.where(text_name: genus_name)
          accepted   = genera.reject(&:deprecated)
          genera     = accepted if accepted.any?
          nonsensu   = genera.reject { |n| n.author.start_with?("sensu ") }
          genera     = nonsensu if nonsensu.any?
          genera.first
        end
      end
  end

  # Returns an Array of all Name's in the rank above that contain this Name.
  # If there are multiple names at a given rank, it prefers accepted, non-sensu
  # names, but beyond that it chooses the first one arbitrarily.  It ignores
  # misspellings.
  #
  #    child = Name.find_by_text_name('Letharia vulpina')
  #    child.parents.each do |parent|
  #      puts parent.text_name
  #    end
  #
  #    # Produces:
  #    Letharia (First) Author
  #    Letharia (Another) One
  #
  # NOTE: This method previously "climbed the tree", looking up each parent
  # in the classification string sequentially, running up to 14 new queries
  # of the Name table and slowing down the show_name page noticeably.
  # It's been painstakingly refactored to batch those lookups and select the
  # matches from a single set of results. Very time consuming!
  # Bonus for the naming emails query (doesn't work yet, though):
  # Now allows eager loading (interests), plus adding self and "Lichen".
  def parents(all: false, add_self: false, add_lichen: false, includes: [])
    parents = []
    text_names = add_self ? [text_name] : []

    # Start with infrageneric and genus names.
    # Get rid of quoted words and ssp., var., f., etc.
    words = text_name.split - %w[group clade complex]
    words.pop
    until words.empty?
      name = words.join(" ")
      words.pop
      next if name == text_name || name[-1] == "."

      # Maintain ascending order in case we want the immediate parent
      text_names << name
    end

    # Next grab the names out of the classification string.
    lines = try(&:parse_classification) || []
    reverse_names = lines.reverse.map { |(_rank, line_name)| line_name }
    text_names += reverse_names
    text_names << "Lichen" if add_lichen

    # Do the batch lookup. This is a bit longer than "climbing the tree" if we
    # just want one parent and the first result would've been an approved name,
    # but way shorter if the first one is deprecated or we need more parents.
    parents += Name.best_matches_from_array(text_names, includes)

    # Get rid of deprecated names unless all the results are deprecated.
    parents.reject!(&:deprecated) unless parents.all?(&:deprecated)

    # Return single parent as an array for backwards compatibility.
    return parents.uniq if all
    return [] unless parents.any?

    [parents.first]
  end

  # Returns an Array of Name's directly under this one.  Ignores misspellings,
  # but includes deprecated Name's.
  #
  #   parent = Name.find_by_text_name('Letharia')
  #   parent.children.each do |child|
  #     puts child.text_name
  #   end
  #
  #   # Produces:
  #   'Letharia californica'
  #   'Letharia columbiana'
  #   'Letharia lupina'
  #   'Letharia vulpina'
  #
  #   parent = Name.find_by_text_name('Letharia vulpina')
  #   parent.children.each do |child|
  #     puts child.text_name
  #   end
  #
  #   # Produces:
  #   'Letharia vulpina var. bogus'
  #   'Letharia vulpina f. californica'
  #
  #   # BUT NOT THIS!!
  #   'Letharia vulpina var. bogus f. foobar'
  #
  def children(all: false)
    scoped_children = correctly_spelled_subtaxa

    return scoped_children.to_a if all

    Name.all_ranks.reverse_each do |rank2|
      next if rank_index(rank2) >= rank_index(rank)

      matches = scoped_children.with_rank(rank2)
      return matches.to_a if matches.any?
    end
    []
  end

  # Pass off to class method of the same name.
  def validate_classification(str = nil)
    self.class.validate_classification(str || classification)
  end

  # Pass off to class method of the same name.
  def parse_classification(str = nil)
    self.class.parse_classification(str || classification)
  end

  # Does this Name have notes (presumably discussing taxonomy).
  def has_notes?
    notes&.match(/\S/)
  end

  # Copy classification from parent.  Just take parent's classification string
  # and add the parent's name to the bottom of it.  Nice and easy.
  def inherit_classification(parent)
    raise("missing parent!")               unless parent
    raise("only do this on genera or up!") if below_genus?
    raise("parent has no classification!") if parent.classification.blank?

    str = parent.classification.to_s.sub(/\s+\z/, "")
    str += "\r\n#{parent.rank}: _#{parent.text_name}_\r\n"
    change_classification(str)
  end

  # Change this name's classification.  Change its synonyms and its parent
  # genus, too, if below genus.  Propagate to subtaxa if at or below genus.
  def change_classification(new_str)
    root = below_genus? && accepted_genus || self
    root.synonyms.each do |name|
      name.update(classification: new_str)
      name.description.update(classification: new_str) if name.description_id
    end
    root.propagate_classification if root.rank == "Genus"
  end

  # Copy the classification of a genus to all of its children.  Does not change
  # updated_at or rss_log or anything.  Just changes the classification field
  # in the name and default description records.
  def propagate_classification
    raise("Name#propagate_classification only works on genera for now.") \
      if rank != "Genus"

    subtaxa = subtaxa_whose_classification_needs_to_be_changed
    Name.where(id: subtaxa).
      update_all(classification: classification)
    NameDescription.where(name_id: subtaxa).
      update_all(classification: classification)
    Observation.where(name_id: subtaxa).
      update_all(classification: classification)
  end

  # Get list of subtaxa whose classification doesn't match (and therefore
  # needs to be updated to be in sync with this name).  Start with approved
  # names below genus with the same generic epithet.  Then add all those
  # names' synonyms.
  def subtaxa_whose_classification_needs_to_be_changed
    subtaxa = Name.subtaxa_of_genus_or_below(text_name).not_deprecated.to_a
    uniq_subtaxa = subtaxa.filter_map(&:synonym_id).uniq
    # Beware of AR where.not gotcha - will not match a null classification below
    synonyms = Name.where(deprecated: true, synonym_id: uniq_subtaxa).
               where(Name[:classification].not_eq(classification))
    (subtaxa + synonyms).map(&:id).uniq
  end

  # ----------------------------------------------------------------------------

  # Does another Name "depend" on this Name?
  def dependents?
    approved_synonym_of_correctly_spelt_proposed_name? ||
      correctly_spelled_ancestor_of_proposed_name? ||
      ancestor_of_correctly_spelled_name?
  end

  ################

  private

  def correctly_spelled_subtaxa
    if at_or_below_genus?
      Name.with_correct_spelling.subtaxa_of_genus_or_below(text_name)
    else
      Name.with_correct_spelling.
        with_rank_and_name_in_classification(rank, text_name)
    end
  end

  def approved_synonym_of_correctly_spelt_proposed_name?
    !deprecated &&
      Naming.joins(:name).where(name: other_synonyms).
        merge(Name.with_correct_spelling).any?
  end

  def ancestor_of_correctly_spelled_name?
    correctly_spelled_subtaxa.any?
  end

  def correctly_spelled_ancestor_of_proposed_name?
    return false if correct_spelling.present?
    return above_genus_is_ancestor? unless at_or_below_genus?
    return genus_or_species_is_ancestor? if %w[Genus Species].include?(rank)

    false
  end

  def above_genus_is_ancestor?
    Name.joins(:namings).
      with_rank_and_name_in_classification(rank, text_name).any?
  end

  def genus_or_species_is_ancestor?
    Name.joins(:namings).subtaxa_of_genus_or_below(text_name).
      with_rank_below(rank).any?
  end

  module ClassMethods
    def all_ranks
      ranks.map do |name, _integer|
        name
      end
    end

    # Returns a Hash mapping alternative ranks to standard ranks (all Symbol's).
    def alt_ranks
      { Division: "Phylum" }
    end

    def ranks_above_genus
      %w[Family Order Class Phylum Kingdom Domain Group]
    end

    def ranks_between_kingdom_and_genus
      %w[Phylum Subphylum Class Subclass Order Suborder Family]
    end

    def ranks_above_species
      %w[Stirps Subsection Section Subgenus Genus
         Family Order Class Phylum Kingdom Domain]
    end

    def ranks_below_genus
      %w[Form Variety Subspecies Species Stirps Subsection Section Subgenus]
    end

    def ranks_below_species
      %w[Form Variety Subspecies]
    end

    def rank_index(rank)
      Name.all_ranks.index(rank)
    end

    def compare_ranks(rank_a, rank_b)
      all_ranks.index(rank_a) <=> all_ranks.index(rank_b)
    end

    def translate_rank(rank)
      "rank_#{rank}".downcase.to_sym.l
    end

    # Handy method which searches for a plain old text name and picks the "best"
    # version available.  That is, it ignores misspellings, chooses accepted,
    # non-"sensu" names where possible, and finally picks the first one
    # arbitrarily where there is still ambiguity.  Useful if you just need a
    # name and it's not so critical that it be the exactly correct one.
    def best_match(name, includes = [])
      all = batch_lookup_all_matches(name, includes)

      best_match_accepted_or_nonsensu(name, all)
    end

    # Does the above with a list (like parents) - does a single batch lookup,
    # then loops over them and returns the matches
    def best_matches_from_array(names, includes = [])
      all = batch_lookup_all_matches(names, includes)

      best = names.map do |name|
        best_match_accepted_or_nonsensu(name, all)
      end
      # must compact. best_match_accepted_or_nonsensu may return nil
      best.compact
    end

    # Batch lookup of any name matching the given name or names (strings)
    # Refactored to do a single db lookup, rather than two.
    # Now allows includes, for batch lookup of Naming email interested parties
    # GOTCHA: `search_name` cannot be used as a field in this AR where clause
    def batch_lookup_all_matches(name_or_names, includes = [])
      Name.where(Name[:search_name].in(name_or_names)).
        or(Name.where(Name[:text_name].in(name_or_names))).
        with_correct_spelling.includes(includes)
    end

    # NOTE: may return nil if no match
    def best_match_accepted_or_nonsensu(name, all)
      matches = all.select { |match| match.search_name == name }
      unless matches.any?
        matches  = all.select { |match| match.text_name == name }
        accepted = matches.reject(&:deprecated)
        matches  = accepted if accepted.any?
        nonsensu = matches.reject { |match| match.author.start_with?("sensu ") }
        matches  = nonsensu if nonsensu.any?
      end
      matches.first
    end

    # Parse the given +classification+ String, validate it, and reformat it so
    # that it is standardized.  Return the reformatted String.  Throws a
    # RuntimeError if there are any errors.
    #
    # rank::  Ensure all Names are of higher rank than this.
    # text::  The +classification+ String.
    #
    # Example output:
    #
    #   Domain: _Eukarya_\r\n
    #   Kingdom: _Fungi_\r\n
    #   Phylum: _Basidiomycota_\r\n
    #   Class: _Basidomycotina_\r\n
    #   Order: _Agaricales_\r\n
    #   Family: _Agaricaceae_\r\n
    #
    # rubocop:disable Metrics/MethodLength
    def validate_classification(rank, text)
      result = text
      if text
        parsed_names = {}
        if rank_index(rank).nil?
          raise(:runtime_user_bad_rank.t(rank: rank.to_s))
        end

        rank_idx = [rank_index("Genus"), rank_index(rank)].max
        rank_str = Name.translate_rank(rank)

        # Check parsed output to make sure ranks are correct, names exist, etc.
        kingdom = "Fungi"
        parse_classification(text).each do |line_rank, line_name|
          real_rank = Name.guess_rank(line_name)
          real_rank_str = Name.translate_rank(real_rank)
          expect_rank = if ranks_between_kingdom_and_genus.include?(line_rank)
                          line_rank
                        else
                          "Genus" # cannot guess Kingdom or Domain
                        end
          line_rank_idx = rank_index(line_rank)
          if line_rank_idx.nil?
            raise(:runtime_user_bad_rank.t(rank: line_rank.to_s))
          end

          line_rank_str = Name.translate_rank(line_rank)

          if line_rank_idx <= rank_idx
            raise(:runtime_invalid_rank.t(line_rank: line_rank_str,
                                          rank: rank_str))
          end
          if parsed_names[line_rank]
            raise(:runtime_duplicate_rank.t(rank: line_rank_str))
          end

          if real_rank != expect_rank && kingdom == "Fungi"
            raise(:runtime_wrong_rank.t(expect: line_rank_str,
                                        actual: real_rank_str, name: line_name))
          end
          parsed_names[line_rank] = line_name
          kingdom = line_name if line_rank == "Kingdom"
        end

        # Reformat output, writing out lines in correct order.
        if parsed_names != {}
          result = ""
          Name.all_ranks.reverse_each do |r|
            if (name = parsed_names[r])
              result += "#{r}: _#{name}_\r\n"
            end
          end
          result.strip!
        end
      end
      result
    end
    # rubocop:enable Metrics/MethodLength

    # Parses the Classification String to eturns an Array of pairs of values.
    #
    #  [["Kingdom", "Fungi"], ["Phylum", "Basidiomycota"],
    #   ["Class", "Basidiomycetes"]]
    #
    # String syntax is a bunch of lines of the form "rank: name":
    #
    #   Kingdom: Fungi
    #   Order: Agaricales
    #   Family: Agaricaceae
    #
    # It strips out excess whitespace.  Names can be surrounded by underscores.
    # It throws a RuntimeError if there are any syntax errors.
    #
    #   lines = Name.parse_classification(str)
    #   for (rank, name) in lines
    #     # rank = "Family"
    #     # name = "Agaricaceae"
    #   end
    #
    def parse_classification(text)
      results = []
      if text
        alt_ranks = Name.alt_ranks
        text.split(/\r?\n/).each do |line|
          match = line.match(/^\s*([a-zA-Z]+):\s*_*([a-zA-Z]+)_*\s*$/)
          if match
            line_rank = match[1].downcase.capitalize
            if (alt_rank = alt_ranks[line_rank])
              line_rank = alt_rank
            end
            line_name = match[2]
            results.push([line_rank, line_name])
          elsif line.present?
            raise(:runtime_invalid_classification.t(text: line))
          end
        end
      end
      results
    end

    # This is meant to be run nightly to ensure that all the classification
    # caches are up to date.  It only pays attention to genera or higher.
    def refresh_classification_caches(dry_run: false)
      query = Name.has_description_classification_differing
      msgs = query.map do |name|
        "Classification for #{name.search_name} didn't match description."
      end
      unless dry_run || msgs.none?
        query.update_all(
          Name[:classification].eq(NameDescription[:classification]).to_sql
        )
      end
      msgs
    end
  end
end
