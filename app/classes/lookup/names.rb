# frozen_string_literal: true

class Lookup::Names < Lookup
  def initialize(vals, params = {})
    @model = Name
    @name_column = :search_name
    super
  end

  def prepare_vals(vals)
    if vals.blank?
      complain_about_unused_flags!
      return []
    end

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

  # If we got params, look up all instances from the ids.
  def lookup_instances
    return [] if @vals.blank?

    ids.map { |id| Name.find(id) }
  end

  def original_names
    @original_names ||= if @params[:exclude_original_names]
                          add_other_spellings(original_matches)
                        else
                          original_matches
                        end
  end

  def original_matches
    @original_matches ||= @vals.map do |val|
      if val.is_a?(@model)
        val.id
      elsif val.is_a?(AbstractModel)
        raise("Passed a #{val.class} to LookupIDs for #{@model}.")
      elsif /^\d+$/.match?(val.to_s) # from an id
        Name.where(id: val).select(*minimal_name_columns)
      else # from a string
        find_matching_names(val)
      end
    end.flatten.uniq.compact
  end

  # NOTE: Name.parse_name returns a ParsedName instance which is a hash of
  # various parts/formats of the name, NOT an Name instance
  def find_matching_names(name)
    parse = Name.parse_name(name)
    srch_str = if parse
                 parse.search_name
               else
                 Name.clean_incoming_string(name)
               end
    if parse&.author.present?
      matches = Name.where(search_name: srch_str).select(*minimal_name_columns)
    end
    return matches unless matches.empty?

    Name.where(text_name: srch_str).select(*minimal_name_columns)
  end

  def add_synonyms_if_necessary(names)
    if @params[:include_synonyms]
      add_synonyms(names)
    elsif !@params[:exclude_original_names]
      add_other_spellings(names)
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
      add_other_spellings(names_plus_subtaxa)
    end
  end

  def add_other_spellings(names)
    ids = names.map { |name| name[:correct_spelling_id] || name[:id] }
    return [] if ids.empty?

    Name.where(Name[:correct_spelling_id].coalesce(Name[:id]).
               in(limited_id_set(ids))).select(*minimal_name_columns)
  end

  def add_synonyms(names)
    ids = names.pluck(:synonym_id).compact
    return names if ids.empty?

    names.reject { |name| name[:synonym_id] } +
      Name.where(synonym_id: limited_id_set(ids)).
      select(*minimal_name_columns)
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

  # This ugliness with "minimal name data" is a way to avoid having Rails
  # instantiate all the names (which can get quite huge if you start talking
  # about all the children of Kingdom Fungi!)  It allows us to use low-level
  # mysql queries, and restricts the dataflow back and forth to the database
  # to just the few columns we actually need.  Unfortunately it is ugly,
  # it totally violates the autonomy of Name, and it is probably hard to
  # understand.  But hopefully once we get it working it will remain stable.
  # Blame it on me... -Jason, July 2019

  # def minimal_name_data(name)
  #   return nil unless name

  #   [
  #     name.id,                   # 0
  #     name.correct_spelling_id,  # 1
  #     name.synonym_id,           # 2
  #     name.text_name             # 3
  #   ]
  # end

  def minimal_name_columns
    [:id, :correct_spelling_id, :synonym_id, :text_name]
  end

  # array of max of MO.query_max_array unique ids for use with Arel "in"
  #    where(<x>.in(limited_id_set(ids)))
  def limited_id_set(ids)
    ids.map(&:to_i).uniq[0, MO.query_max_array]
  end

  def complain_about_unused_flags!
    complain_about_unused_flag!(:include_synonyms)
    complain_about_unused_flag!(:include_subtaxa)
    complain_about_unused_flag!(:include_nonconsensus)
    complain_about_unused_flag!(:exclude_consensus)
    complain_about_unused_flag!(:exclude_original_names)
  end

  def complain_about_unused_flag!(param)
    return if @params.blank? || @params[param].nil?

    raise("Flag \"#{param}\" is invalid without \"names\" parameter.")
  end
end
