# frozen_string_literal: true

class Name < AbstractModel
  scope :with_classification_like,
        # Use multi-line lambda literal because fixtures blow up with "lambda":
        # NoMethodError: undefined method `ranks'
        #   test/fixtures/names.yml:28:in `get_binding'
        ->(rank, text_name) { # rubocop:disable Style/Lambda
          where "classification LIKE ?", "%#{rank}: _#{text_name}_%"
        }
  scope :with_rank_below,
        ->(rank) { where("`rank` < ?", Name.ranks[rank]) }

  def self.all_ranks
    [:Form, :Variety, :Subspecies, :Species,
     :Stirps, :Subsection, :Section, :Subgenus, :Genus,
     :Family, :Order, :Class, :Phylum, :Kingdom, :Domain,
     :Group]
  end

  # Returns a Hash mapping alternative ranks to standard ranks (all Symbol's).
  def self.alt_ranks
    { Division: :Phylum }
  end

  def self.ranks_above_genus
    [:Family, :Order, :Class, :Phylum, :Kingdom, :Domain, :Group]
  end

  def self.ranks_between_kingdom_and_genus
    [:Phylum, :Subphylum, :Class, :Subclass, :Order, :Suborder, :Family]
  end

  def self.ranks_above_species
    [:Stirps, :Subsection, :Section, :Subgenus, :Genus,
     :Family, :Order, :Class, :Phylum, :Kingdom, :Domain]
  end

  def self.ranks_below_genus
    [:Form, :Variety, :Subspecies, :Species,
     :Stirps, :Subsection, :Section, :Subgenus]
  end

  def self.ranks_below_species
    [:Form, :Variety, :Subspecies]
  end

  def at_or_below_genus?
    rank == :Genus || below_genus?
  end

  def below_genus?
    Name.ranks_below_genus.include?(rank) ||
      rank == :Group && text_name.include?(" ")
  end

  def between_genus_and_species?
    below_genus? && !at_or_below_species?
  end

  def at_or_below_species?
    (rank == :Species) || Name.ranks_below_species.include?(rank)
  end

  def self.rank_index(rank)
    Name.all_ranks.index(rank.to_sym)
  end

  def rank_index(rank)
    Name.all_ranks.index(rank.to_sym)
  end

  def self.compare_ranks(rank_a, rank_b)
    all_ranks.index(rank_a.to_sym) <=> all_ranks.index(rank_b.to_sym)
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
        return true if d.review_status == :vetted && d.ok_for_export && d.public
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
    rank == :Group ||
      rank == :Domain ||
      unpublished? ||
      # name includes quote marks, but limit this to below Order in order to
      # account for things like "Discomycetes", which is registered & quoted
      /"/ =~ text_name && rank >= :Class ||
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
      rank == :Domain ||
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
    return text_name if rank == :Kingdom

    parse_classification.find { |rank| rank.first == :Kingdom }&.last
  end

  public

  # ----------------------------------------------------------------------------

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
  def all_parents
    parents(:all)
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
    children(:all)
  end

  # Returns the Name of the genus above this taxon.  If there are multiple
  # matching genera, it prefers accepted ones that are not "sensu xxx".
  # Beyond that it just chooses the first one arbitrarily.
  def genus
    @genus ||= begin
      accepted   = deprecated ? approved_synonyms.first : self
      return unless accepted.text_name.include?(" ")

      genus_name = accepted.text_name.split(" ", 2).first
      genera     = Name.with_correct_spelling.where(text_name: genus_name)
      accepted   = genera.reject(&:deprecated)
      genera     = accepted if accepted.any?
      nonsensu   = genera.reject { |n| n.author.start_with?("sensu ") }
      genera     = nonsensu if nonsensu.any?
      genera.first
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
  def parents(all = false)
    parents = []

    # Start with infrageneric and genus names.
    # Get rid of quoted words and ssp., var., f., etc.
    words = text_name.split(" ") - %w[group clade complex]
    words.pop
    until words.empty?
      name = words.join(" ")
      words.pop
      next if name == text_name || name[-1] == "."

      parent = Name.best_match(name)
      parents << parent if parent
      return [parent] if !all && parent && !parent.deprecated
    end

    # Next grab the names out of the classification string.
    lines = try(&:parse_classification) || []
    lines.reverse_each do |(_line_rank, line_name)|
      parent = Name.best_match(line_name)
      parents << parent if parent
      return [parent] if !all && !parent.deprecated
    end

    # Get rid of deprecated names unless all the results are deprecated.
    parents.reject!(&:deprecated) unless parents.all?(&:deprecated)

    # Return single parent as an array for backwards compatibility.
    return parents if all
    return [] unless parents.any?

    [parents.first]
  end

  # Handy method which searches for a plain old text name and picks the "best"
  # version available.  That is, it ignores misspellings, chooses accepted,
  # non-"sensu" names where possible, and finally picks the first one
  # arbitrarily where there is still ambiguity.  Useful if you just need a
  # name and it's not so critical that it be the exactly correct one.
  def self.best_match(name)
    matches = Name.with_correct_spelling.where(search_name: name)
    return matches.first if matches.any?

    matches  = Name.with_correct_spelling.where(text_name: name)
    accepted = matches.reject(&:deprecated)
    matches  = accepted if accepted.any?
    nonsensu = matches.reject { |match| match.author.start_with?("sensu ") }
    matches  = nonsensu if nonsensu.any?
    matches.first
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
  def children(all = false)
    if at_or_below_genus?
      sql_conditions = "correct_spelling_id IS NULL AND text_name LIKE ? "
      sql_args = "#{text_name} %"
    else
      sql_conditions = "correct_spelling_id IS NULL AND classification LIKE ?"
      sql_args = "%#{rank}: _#{text_name}_%"
    end

    return Name.where(sql_conditions, sql_args).to_a if all

    Name.all_ranks.reverse_each do |rank2|
      next if rank_index(rank2) >= rank_index(rank)

      matches = Name.with_rank(rank2).where(sql_conditions, sql_args)
      return matches.to_a if matches.any?
    end
    []
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
  def self.validate_classification(rank, text)
    result = text
    if text
      parsed_names = {}
      raise(:runtime_user_bad_rank.t(rank: rank.to_s)) if rank_index(rank).nil?

      rank_idx = [rank_index(:Genus), rank_index(rank)].max
      rank_str = "rank_#{rank}".downcase.to_sym.l

      # Check parsed output to make sure ranks are correct, names exist, etc.
      kingdom = "Fungi"
      parse_classification(text).each do |line_rank, line_name|
        real_rank = Name.guess_rank(line_name)
        real_rank_str = "rank_#{real_rank}".downcase.to_sym.l
        expect_rank = if ranks_between_kingdom_and_genus.include?(line_rank)
                        line_rank
                      else
                        :Genus # cannot guess Kingdom or Domain
                      end
        line_rank_idx = rank_index(line_rank)
        if line_rank_idx.nil?
          raise(:runtime_user_bad_rank.t(rank: line_rank.to_s))
        end

        line_rank_str = "rank_#{line_rank}".downcase.to_sym.l

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
        kingdom = line_name if line_rank == :Kingdom
      end

      # Reformat output, writing out lines in correct order.
      if parsed_names != {}
        result = ""
        Name.all_ranks.reverse_each do |rank|
          if (name = parsed_names[rank])
            result += "#{rank}: _#{name}_\r\n"
          end
        end
        result.strip!
      end
    end
    result
  end

  # Parses the Classification String to eturns an Array of pairs of values.
  #
  #  [[:Kingdom, "Fungi"], [:Phylum, "Basidiomycota"],
  #   [:Class, "Basidiomycetes"]]
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
  #     # rank = :Family
  #     # name = "Agaricaceae"
  #   end
  #
  def self.parse_classification(text)
    results = []
    if text
      alt_ranks = Name.alt_ranks
      text.split(/\r?\n/).each do |line|
        match = line.match(/^\s*([a-zA-Z]+):\s*_*([a-zA-Z]+)_*\s*$/)
        if match
          line_rank = match[1].downcase.capitalize.to_sym
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

  def text_before_rank
    text_name.split(" #{rank.to_s.downcase}").first
  end

  # This is called before a name is created to let us populate things like
  # classification and lifeform from the parent (if infrageneric only).
  def inherit_stuff
    return unless genus # this sets the name instance @genus as side-effect

    self.classification ||= genus.classification
    self.lifeform       ||= genus.lifeform
  end

  # Let attached observations update their cache if these fields changed.
  def update_observation_cache
    Observation.update_cache("name", "lifeform", id, lifeform) \
      if lifeform_changed?
    Observation.update_cache("name", "text_name", id, text_name) \
      if text_name_changed?
    Observation.update_cache("name", "classification", id, classification) \
      if classification_changed?
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

  # Change this name's classification.  Change parent genus, too, if below
  # genus.  Propagate to subtaxa if changing genus.
  def change_classification(new_str)
    root = below_genus? && genus || self
    root.update(classification: new_str)
    root.description.update(classification: new_str) if
      root.description_id
    root.propagate_classification if root.rank == :Genus
  end

  # Copy the classification of a genus to all of its children.  Does not change
  # updated_at or rss_log or anything.  Just changes the classification field
  # in the name and default description records.
  def propagate_classification
    raise("Name#propagate_classification only works on genera for now.") \
      if rank != :Genus

    escaped_string = Name.connection.quote(classification)
    Name.connection.execute(%(
      UPDATE names SET classification = #{escaped_string}
      WHERE text_name LIKE "#{text_name} %"
        AND classification != #{escaped_string}
    ))
    Name.connection.execute(%(
      UPDATE name_descriptions nd, names n
      SET nd.classification = #{escaped_string}
      WHERE nd.id = n.description_id
        AND n.text_name LIKE "#{text_name} %"
        AND nd.classification != #{escaped_string}
    ))
    Name.connection.execute(%(
      UPDATE observations
      SET classification = #{escaped_string}
      WHERE text_name LIKE "#{text_name} %"
        AND classification != #{escaped_string}
    ))
  end

  # This is meant to be run nightly to ensure that all the classification
  # caches are up to date.  It only pays attention to genera or higher.
  def self.refresh_classification_caches
    Name.connection.execute(%(
      UPDATE names n, name_descriptions nd
      SET n.classification = nd.classification
      WHERE nd.id = n.description_id
        AND n.`rank` <= #{Name.connection.quote(Name.ranks[:Genus])}
        AND nd.classification != n.classification
        AND COALESCE(nd.classification, "") != ""
    ))
    []
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

  def approved_synonym_of_correctly_spelt_proposed_name?
    !deprecated &&
      Naming.joins(:name).where(name: other_synonyms).
        merge(Name.with_correct_spelling).any?
  end

  def ancestor_of_correctly_spelled_name?
    if at_or_below_genus?
      Name.where("text_name LIKE ?", "#{text_name} %").
        with_correct_spelling.any?
    else
      Name.with_classification_like(rank, text_name).with_correct_spelling.any?
    end
  end

  def correctly_spelled_ancestor_of_proposed_name?
    return false if correct_spelling.present?
    return above_genus_is_ancestor? unless at_or_below_genus?
    return genus_or_species_is_ancestor? if [:Genus, :Species].include?(rank)

    false
  end

  def above_genus_is_ancestor?
    Name.joins(:namings).with_classification_like(rank, text_name).any?
  end

  def genus_or_species_is_ancestor?
    Name.joins(:namings).where("text_name LIKE ?", "#{text_name} %").
      with_rank_below(rank).any?
  end
end
