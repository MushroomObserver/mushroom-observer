class Name < AbstractModel
  # Short-hand for calling Name.find_names with +fill_in_authors+ set to +true+.
  def self.find_names_filling_in_authors(in_str, rank = nil,
                                         ignore_deprecated = false)
    find_names(in_str, rank, ignore_deprecated, :fill_in_authors)
  end

  # Look up Name's with a given name.  By default tries to weed out deprecated
  # Name's, but if that results in an empty set, then it returns the deprecated
  # ones. Returns an Array of zero or more Name instances.
  #
  # +in_str+::              String to parse.
  # +rank+::                Accept only names of this rank (optional).
  # +ignore_deprecated+::   If +true+, return all matching names,
  #                         even if deprecated.
  # +fill_in_authors+::     If +true+, will fill in author for Name's missing
  #                         authors
  #                         if +in_str+ supplies one.
  #
  #  names = Name.find_names('Letharia vulpina')
  #
  def self.find_names(in_str, rank = nil, ignore_deprecated = false,
                      fill_in_authors = false)

    return [] unless parse = parse_name(in_str)

    text_name = parse.text_name
    search_name = parse.search_name
    author = parse.author
    results = []

    while results.empty?
      conditions = []
      conditions_args = {}
      if author.present?
        conditions << "search_name = :name"
        conditions_args[:name] = search_name
      else
        conditions << "text_name = :name"
        conditions_args[:name] = text_name
      end
      conditions << "deprecated = 0" unless ignore_deprecated
      conditions << "rank = #{Name.ranks[rank]}" if rank

      results = Name.where(conditions.join(" AND "), conditions_args).to_a

      # If user provided author, check if name already exists without author.
      if author.present? && results.empty?
        conditions_args[:name] = text_name
        results = Name.where(conditions.join(" AND "), conditions_args).to_a
        # (this should never return more than one result)
        if fill_in_authors && results.length == 1
          results.first.change_author(author)
          results.first.save
        end
      end

      # Try again, looking for deprecated names
      # if didn't find any matching approved names.
      break if ignore_deprecated
      ignore_deprecated = true
    end

    results
  end

  # Parses a String, creates a Name for it and all its ancestors (if any don't
  # already exist), returns it in an Array (genus first, then species, etc.  If
  # there is ambiguity at any level (due to different authors), then +nil+ is
  # returned in that slot.  Check last slot especially.  Returns an Array of
  # Name instances, *UNSAVED*!!
  #
  #   names = Name.find_or_create_name_and_parents('Letharia vulpina (L.) Hue')
  #   raise "Name is ambiguous!" if !names.last
  #   names.each do |name|
  #     name.save if name and name.new_record?
  #   end
  #
  def self.find_or_create_name_and_parents(in_str)
    result = []
    if (parsed_name = parse_name(in_str))
      result = find_or_create_parsed_name_and_parents(parsed_name)
    end
    result
  end

  def self.find_or_create_parsed_name_and_parents(parsed_name)
    result = []
    if names_for_unknown.member?(parsed_name.search_name.downcase)
      result << Name.unknown
    else
      if parsed_name.parent_name
        result = find_or_create_name_and_parents(parsed_name.parent_name)
      end
      deprecate = result.any? && result.last && result.last.deprecated
      result << find_or_create_parsed_name(parsed_name, deprecate)
    end
    result
  end

  def self.find_or_create_parsed_name(parsed_name, deprecate = false)
    result = nil
    matches = find_matching_names(parsed_name)
    if matches.empty?
      result = Name.make_name(parsed_name.params)
      result.change_deprecated(true) if deprecate
    elsif matches.length == 1
      result = matches.first
      # Fill in author automatically if we can.
      if result.author.blank? && parsed_name.author.present?
        result.change_author(parsed_name.author)
      end
    else
      # Try to resolve ambiguity by taking the one with author.
      matches.reject! { |name| name.author.blank? }
      result = matches.first if matches.length == 1
    end
    result
  end

  def self.find_matching_names(parsed_name)
    result = []
    if parsed_name.author.blank?
      result = Name.where(text_name: parsed_name.text_name)
    else
      result = Name.where(search_name: parsed_name.search_name)
      if result.empty?
        result = Name.where(text_name: parsed_name.text_name, author: "")
      end
    end
    result.to_a
  end

  # Look up a Name, creating it as necessary.  Requires +rank+ and +text_name+,
  # at least, supplying defaults for +search_name+, +display_name+, and
  # +sort_name+, and leaving +author+ blank by default.  Requires an
  # exact match of both +text_name+ and +author+. Returns:
  #
  # zero or one matches:: a Name instance, *UNSAVED*!!
  # multiple matches::    nil
  #
  # Used by +make_species+, +make_genus+, and +find_or_create_name_and_parents+.
  #
  def self.make_name(params)
    result = nil
    search_name = params[:search_name]
    matches = Name.where(search_name: search_name)
    if matches.empty?
      result = Name.new_name(params)
    elsif matches.length == 1
      result = matches.first
    end
    result
  end

  # make a Name given all the various name formats, etc.
  # Used only by +make_name+, +new_name_from_parsed_name+, and
  # +create_test_name+ in unit test.
  # Returns a Name instance, *UNSAVED*!!
  def self.new_name(params)
    result = Name.new(params)
    result.created_at = now = Time.now
    result.updated_at = now
    result
  end

  # Make a Name instance from a ParsedName
  # Used by NameController#create_new_name
  # Returns a Name instance, *UNSAVED*!!
  def self.new_name_from_parsed_name(parsed_name)
    new_name(parsed_name.params)
  end

  # Get list of Names that are potential matches when creating a new name.
  # Takes results of Name.parse_name.  Used by NameController#create_name.
  # Three cases:
  #
  #   1. group with author       - only accept exact matches
  #   2. nongroup with author    - match names with correct author or no author
  #   3. any name without author - ignore authors completely when matching names
  #
  # If the user provides an author, but the only match has no author, then we
  # just need to add an author to the existing Name.  If the user didn't give
  # an author, but there are matches with an author, then it already exists
  # and we should just ignore the request.
  #
  def self.names_matching_desired_new_name(parsed_name)
    if parsed_name.rank == :Group
      Name.where(search_name: parsed_name.search_name)
    elsif parsed_name.author.empty?
      Name.where(text_name: parsed_name.text_name)
    else
      Name.where(text_name: parsed_name.text_name).
        where(author: [parsed_name.author, ""])
    end
  end
end
