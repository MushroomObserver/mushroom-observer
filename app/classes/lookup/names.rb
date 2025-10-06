# frozen_string_literal: true

class Lookup::Names < Lookup
  MODEL = Name
  TITLE_METHOD = :text_name

  def prepare_vals(vals)
    return [] if vals.blank?

    [vals].flatten
  end

  def lookup_ids
    return [] if @vals.blank?

    names = add_synonyms_if_necessary(original_names)
    names_plus_subtaxa = add_subtaxa_if_necessary(names)
    names = add_synonyms_again(names, names_plus_subtaxa)
    names -= original_names if @params[:exclude_original_names]
    names.map(&:id)
  end

  # Re-lookup all instances from the matched ids. Too complicated to try to grab
  # instances if they were in the given vals, because of `add_other_spellings`.
  def lookup_instances
    return [] if @vals.blank?

    ids.map { |id| Name.find(id) }
  end

  # "Original" names could turn out to be quite a few more than the given vals.
  # Memoized to avoid recalculating, or passing the value around.
  def original_names
    @original_names ||= if @params[:exclude_original_names]
                          add_other_spellings(original_matches)
                        else
                          original_matches
                        end
  end

  # Matches for the given vals, from the db.
  def original_matches
    @original_matches ||= if numeric_list?(@vals)
                            numeric_matches
                          else
                            map_matches
                          end
  end

  def numeric_matches
    Name.where(id: @vals).distinct.select(*minimal_name_columns)
  end

  def map_matches
    @vals.map do |val|
      if val.is_a?(@model)
        val
      elsif val.is_a?(AbstractModel)
        raise("Passed a #{val.class} to LookupIDs for #{@model}.")
      elsif /^\d+$/.match?(val.to_s) # from an id
        Name.where(id: val).select(*minimal_name_columns)
      else # from a string
        find_matching_names(val)
      end
    end.flatten.uniq.compact
  end

  def numeric_list?(list)
    list.all? do |item|
      case item
      when Numeric
        true
      when String
        # Handles integers only
        item.match?(/^\d+$/)
      else
        false
      end
    end
  end

  # NOTE: Name.parse_name returns a ParsedName instance, not an Name instance.
  # A ParsedName is a hash of segments and formatted strings of the name.
  def find_matching_names(val)
    parse = Name.parse_name(val)
    srch_str = if parse
                 parse.search_name
               else
                 Name.clean_incoming_string(val)
               end
    if parse&.author.present?
      matches = Name.search_name_has(srch_str).select(*minimal_name_columns)
    end
    return matches unless matches.empty?

    Name.text_name_has(srch_str).select(*minimal_name_columns)
  end

  def add_synonyms_if_necessary(names)
    if @params[:include_synonyms]
      add_synonyms(names)
    else
      names
    end
  end

  def add_subtaxa_if_necessary(names)
    if @params[:include_subtaxa]
      add_subtaxa(names)
    elsif @params[:include_immediate_subtaxa]
      add_immediate_subtaxa(names)
    else
      names
    end
  end

  def add_synonyms_again(names, names_plus_subtaxa)
    if names.length >= names_plus_subtaxa.length
      names
    elsif @params[:include_synonyms]
      add_synonyms(names_plus_subtaxa)
    else
      names_plus_subtaxa
    end
  end

  def add_other_spellings(names)
    name_ids = names.map { |name| name[:correct_spelling_id] || name[:id] }
    return [] if name_ids.empty?

    Name.where(Name[:correct_spelling_id].coalesce(Name[:id]).
               in(limited_id_set(name_ids))).select(*minimal_name_columns)
  end

  def add_synonyms(names)
    name_ids = names.pluck(:synonym_id).compact
    return names if name_ids.empty?

    names.reject { |name| name[:synonym_id] } +
      Name.where(synonym_id: limited_id_set(name_ids)).
      distinct.select(*minimal_name_columns)
  end

  def add_subtaxa(names)
    higher_names = genera_and_up(names)
    lower_names = genera_and_down(names)
    @name_query = Name.where(id: names.map(&:id))
    @name_query = add_lower_names(lower_names)
    @name_query = add_higher_names(higher_names) unless higher_names.empty?
    @name_query.distinct.select(*minimal_name_columns)
  end

  def add_lower_names(names)
    @name_query.or(Name.where(Name[:text_name] =~ /^(#{names.join("|")}) /))
  end

  def add_higher_names(names)
    @name_query.or(
      Name.where(Name[:classification] =~ /: _(#{names.join("|")})_/)
    )
  end

  def add_immediate_subtaxa(names)
    higher_names = genera_and_up(names)
    lower_names = genera_and_down(names)

    @name_query = Name.where(id: names.map(&:id))
    @name_query = add_immediate_lower_names(lower_names)
    unless higher_names.empty?
      @name_query = add_immediate_higher_names(higher_names)
    end
    @name_query.distinct.select(*minimal_name_columns)
  end

  def add_immediate_lower_names(lower_names)
    @name_query.or(Name.
      where(Name[:text_name] =~
        /^(#{lower_names.join("|")}) [^[:blank:]]+( [^[:blank:]]+)?$/))
  end

  def add_immediate_higher_names(higher_names)
    @name_query.or(Name.
      where(Name[:classification] =~ /: _(#{higher_names.join("|")})_$/).
      where.not(Name[:text_name].matches("% %")))
  end

  def genera_and_up(names)
    names.pluck(:text_name).
      reject { |name| name.include?(" ") }
  end

  def genera_and_down(names)
    genera = {}
    text_names = names.pluck(:text_name)
    # Make hash of all genera present.
    text_names.each do |text_name|
      genera[text_name] = true unless text_name.include?(" ")
    end
    # Remove species if genus also present.
    text_names.reject do |text_name|
      text_name.include?(" ") && genera[text_name.split.first]
    end.uniq
  end

  # Selecting "minimal_name_columns" is a way to avoid having Rails instantiate
  # all the names getting passed around (which can get quite huge if we've got
  # all the children of Kingdom Fungi!) It allows us to use quicker AR selects,
  # optimized to restrict the dataflow back and forth to the database to just
  # the few columns we actually need.
  def minimal_name_columns
    [:id, :correct_spelling_id, :synonym_id, :text_name]
  end

  # array of max of MO.query_max_array unique name_ids for use with Arel "in"
  #    where(<x>.in(limited_id_set(name_ids)))
  def limited_id_set(name_ids)
    name_ids.map(&:to_i).uniq[0, MO.query_max_array]
  end
end
