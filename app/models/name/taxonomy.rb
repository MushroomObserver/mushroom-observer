class Name < AbstractModel
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
        if o.vote_cache && o.vote_cache >= MO.eol_min_observation_vote
          o.images.each do |i|
            if i.ok_for_export && i.vote_cache &&
               i.vote_cache >= MO.eol_min_image_vote
              return true
            end
          end
        end
      end
      descriptions.each do |d|
        return true if d.review_status == :vetted && d.ok_for_export && d.public
      end
    end
    false
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
      return unless text_name.include?(" ")

      genus_name = text_name.split(" ", 2).first
      genera     = Name.where(text_name: genus_name, correct_spelling_id: nil)
      accepted   = genera.reject(&:deprecated)
      genera     = accepted if accepted.any?
      nonsensu   = genera.reject { |n| n.author =~ /^sensu / }
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
    matches = Name.where(search_name: name, correct_spelling_id: nil)
    return matches.first if matches.any?

    matches  = Name.where(text_name: name, correct_spelling_id: nil)
    accepted = matches.reject(&:deprecated)
    matches  = accepted if accepted.any?
    nonsensu = matches.reject { |match| match.author =~ /^sensu / }
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
    sql = if at_or_below_genus?
            "text_name LIKE '#{text_name} %'"
          else
            "classification LIKE '%#{rank}: _#{text_name}_%'"
          end
    sql += " AND correct_spelling_id IS NULL"
    return Name.where(sql).to_a if all

    Name.all_ranks.reverse_each do |rank2|
      next if rank_index(rank2) >= rank_index(rank)

      matches = Name.where("rank = #{Name.ranks[rank2]} AND #{sql}")
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
      raise :runtime_user_bad_rank.t(rank: rank) if rank_index(rank).nil?

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
        line_rank_str = "rank_#{line_rank}".downcase.to_sym.l
        line_rank_idx = rank_index(line_rank)
        if line_rank_idx.nil?
          raise :runtime_user_bad_rank.t(rank: line_rank_str)
        end

        if line_rank_idx <= rank_idx
          raise :runtime_invalid_rank.t(line_rank: line_rank_str,
                                        rank: rank_str)
        end
        if parsed_names[line_rank]
          raise :runtime_duplicate_rank.t(rank: line_rank_str)
        end

        if real_rank != expect_rank && kingdom == "Fungi"
          raise :runtime_wrong_rank.t(expect: line_rank_str,
                                      actual: real_rank_str, name: line_name)
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

  # Parse a +classification+ string.  Returns an Array of pairs of values.
  # Syntax is a bunch of lines of the form "rank: name":
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
          raise :runtime_invalid_classification.t(text: line)
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
    text_name.split(" " + rank.to_s.downcase).first
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
    root.update_attributes(classification: new_str)
    root.description.update_attributes(classification: new_str) if
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
        AND n.rank <= #{Name.ranks[:Genus]}
        AND nd.classification != n.classification
        AND COALESCE(nd.classification, "") != ""
    ))
    []
  end

  # # This is meant to be run nightly to ensure that all the infrageneric
  # # classifications are up-to-date with respect to their genera.  This is
  # # important because there is no way to edit this on-line.  (Although there
  # # will be a "propagate classification" button on the genera, and maybe we
  # # can add that to the children, as well.)
  # def self.propagate_generic_classifications
  #
  #   # Refresh classification for genera from descriptions.
  #   Name.connection.execute(%(
  #     UPDATE names n, name_descriptions nd
  #     SET n.classification = nd.classification
  #     WHERE nd.id = n.description_id
  #       AND n.rank = #{Name.ranks[:Genus]}
  #       AND nd.classification != n.classification
  #       AND nd.updated_at > n.updated_at
  #   ))
  #
  #   # Grab all genera with classifications.
  #   genera = {}
  #   Name.where(rank: Name.ranks[:Genus],
  #              correct_spelling_id: nil).each do |name|
  #     next if name.classification.blank?
  #     genera[name.text_name] ||= []
  #     genera[name.text_name] << name
  #   end
  #
  #   # Choose best name to use for each genus.
  #   best = {}
  #   genera.each do |genus, names|
  #     names2 = names.reject(&:deprecated)
  #     names  = names2 if names2.any?
  #     names2 = names.reject { |n| n.author.match(/^sensu/ }
  #     names  = names2 if names2.any?
  #     if names.count > 1
  #       names.sort_by! do |n|
  #         Name.connection.select_value(%(
  #           SELECT COUNT(id) FROM observations WHERE name_id = #{n.id}
  #         )).to_i * -1
  #       end
  #     end
  #     best[names.first.text_name] = names.first
  #   end
  #
  #   # Create map from subtaxa to genus.
  #   rows = []
  #   Name.where(correct_spelling_id: nil).each do |name|
  #     next unless name.below_genus?
  #     genus = best[name.text_name.split(" ", 2).first]
  #     rows << [name.id, genus.id] if genus
  #   end
  #
  #   # Create temporary table.
  #   create_table :temp, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
  #     t.integer :name_id
  #     t.integer :genus_id
  #   end
  #   Name.connection.execute(%(
  #     INSERT INTO temp (name_id, genus_id) VALUES
  #     #{ rows.map { |r| "(#{r[0]},#{r[1]})" }.join(",\n") }
  #   ))
  #
  #   # Get list of errors.
  #   msgs = Name.connection.select_rows(%(
  #     SELECT n1.search_name
  #     FROM names n1, temp t, names n2
  #     WHERE n1.rank < #{Name.ranks[:Genus]}
  #       AND t.name_id = n1.id
  #       AND n2.id = t.genus_id
  #       AND n1.classification != n2.classification
  #   )).map do |name|
  #     "Classification wrong for #{name}."
  #   end
  #
  #   # Propagate generic classifications.
  #   Name.connection.execute(%(
  #     UPDATE names n1, temp t, names n2
  #     SET n1.classification = n2.classification
  #     WHERE n1.rank < #{Name.ranks[:Genus]}
  #       AND t.name_id = n1.id
  #       AND n2.id = t.genus_id
  #   ))
  #
  #   drop_table :temp
  #
  #   # Push classifications for subtaxa to descriptions.
  #   Name.connection.execute(%(
  #     UPDATE names n, name_descriptions nd
  #     SET nd.classification = n.classification
  #     WHERE nd.id = n.description_id
  #       AND COALESCE(n.classification, "") != ""
  #       AND n.rank > #{Name.ranks[:Genus]}
  #   ))
  #
  #   # Refresh observation cache.
  #   Observation.connection.execute(%(
  #     UPDATE observations o, names n
  #     SET o.classification = n.classification
  #     WHERE o.name_id = n.id
  #       AND o.classification != n.classification
  #   ))
  #
  #   msgs
  # end
end
