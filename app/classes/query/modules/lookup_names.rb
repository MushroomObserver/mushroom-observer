# frozen_string_literal: true

# Helper methods to help parsing name instances from parameter strings.
module Query::Modules::LookupNames
  def lookup_names_by_name(args)
    return unless vals = args[:names]

    orig_names = find_exact_name_matches(vals)
    min_names = add_synonyms_or_spellings(orig_names, args[:include_synonyms])
    min_names2 = if args[:include_subtaxa]
                   add_subtaxa(min_names)
                 elsif args[:include_immediate_subtaxa]
                   add_immediate_subtaxa(min_names)
                 end
    if min_names2 && min_names2.length > min_names.length
      min_names = add_synonyms_or_spellings(min_names2, args[:include_synonyms])
    end
    min_names -= orig_names if args[:exclude_original_names]
    min_names.map { |min_name| min_name[0] }
  end

  # ----------------------------------------------------------------------------

  private

  def find_exact_name_matches(vals)
    vals.inject([]) do |result, val|
      if /^\d+$/.match?(val.to_s)
        result << minimal_name_data(Name.safe_find(val))
      else
        result += find_matching_names(val)
      end
    end.uniq.reject(&:nil?)
  end

  def find_matching_names(name)
    parse = Name.parse_name(name)
    name2 = parse ? parse.search_name : Name.clean_incoming_string(name)
    matches = Name.where(search_name: name2)
    matches = Name.where(text_name: name2) if matches.empty?
    matches.map { |name3| minimal_name_data(name3) }
  end

  def minimal_name_data(name)
    return nil unless name

    [
      name.id,                   # 0
      name.correct_spelling_id,  # 1
      name.synonym_id,           # 2
      name.text_name             # 3
    ]
  end

  def minimal_name_columns
    "id, correct_spelling_id, synonym_id, text_name"
  end

  def add_synonyms_or_spellings(min_names, include_synonyms)
    if include_synonyms
      add_synonyms(min_names)
    else
      add_other_spellings(min_names)
    end
  end

  def add_other_spellings(min_names)
    ids = min_names.map { |min_name| min_name[1] || min_name[0] }
    return [] if ids.empty?

    Name.connection.select_rows(%(
      SELECT #{minimal_name_columns} FROM names
      WHERE COALESCE(correct_spelling_id, id) IN (#{clean_id_set(ids)})
    ))
  end

  def add_synonyms(min_names)
    ids = min_names.map { |min_name| min_name[2] }.reject(&:nil?)
    return min_names if ids.empty?

    min_names.reject { |min_name| min_name[2] } +
      Name.connection.select_rows(%(
        SELECT #{minimal_name_columns} FROM names
        WHERE synonym_id IN (#{clean_id_set(ids)})
      ))
  end

  def add_subtaxa(min_names)
    higher_names = genera_and_up(min_names)
    lower_names = genera_and_down(min_names)
    unless higher_names.empty?
      min_names += Name.connection.select_rows(%(
        SELECT #{minimal_name_columns} FROM names
        WHERE classification REGEXP ": _(#{higher_names.join("|")})_"
      ))
    end
    min_names += Name.connection.select_rows(%(
      SELECT #{minimal_name_columns} FROM names
      WHERE text_name REGEXP "^(#{lower_names.join("|")}) "
    ))
    min_names.uniq
  end

  def add_immediate_subtaxa(min_names)
    higher_names = genera_and_up(min_names)
    lower_names = genera_and_down(min_names)
    unless higher_names.empty?
      min_names += Name.connection.select_rows(%(
        SELECT #{minimal_name_columns} FROM names
        WHERE classification REGEXP ": _(#{higher_names.join("|")})_$"
        AND text_name NOT LIKE "% %"
      ))
    end
    min_names += Name.connection.select_rows(%(
      SELECT #{minimal_name_columns} FROM names
      WHERE text_name REGEXP
        "^(#{lower_names.join("|")}) [^[:blank:]]+( [^[:blank:]]+)?$"
    ))
    min_names.uniq
  end

  def genera_and_up(min_names)
    min_names.map { |min_name| min_name[3] }.
      reject { |min_name| min_name.include?(" ") }
  end

  def genera_and_down(min_names)
    genera = {}
    text_names = min_names.map { |min_name| min_name[3] }
    # Make hash of all genera present.
    text_names.each do |text_name|
      genera[text_name] = true unless text_name.include?(" ")
    end
    # Remove species if genus also present.
    text_names.reject do |text_name|
      text_name.include?(" ") && genera[text_name.split(" ").first]
    end.uniq
  end
end
