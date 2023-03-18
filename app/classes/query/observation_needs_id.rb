# frozen_string_literal: true

module Query
  # methods for initializing Queries for Observations Needing Identification
  class ObservationNeedsId < Query::Base
    def parameter_declarations
      super.merge(
        needs_id?: { boolean: [true] },
        needs_id_by_taxon?: Name
      )
    end

    def initialize_flavor
      user = User.current_id
      voted = Observation.with_vote_by_user(user).map(&:id).join(", ")
      reviewed = Observation.reviewed_by_user(user).map(&:id).join(", ")

      where << "observations.id NOT IN (#{voted})" if voted.present?
      where << "observations.id NOT IN (#{reviewed})" if reviewed.present?
      # where << "observations.id NOT IN (SELECT DISTINCT observation_id " \
      #           "FROM observation_views WHERE observation_views.user_id = " \
      #           "#{User.current_id} AND observation_views.reviewed = 1)"
      # where << "observations.id NOT IN (SELECT DISTINCT observation_id " \
      #           "FROM votes WHERE user_id = #{User.current_id})"
      initialize_unfiltered if params[:unfiltered]
      initialize_by_clade if params[:clade]
      initialize_by_region if params[:region]
      super
    end

    # The basic query: any namings with low confidence, or names above genus
    def initialize_unfiltered
      names_above_genus = Name.with_rank_above_genus.map(&:id).join(", ")

      where << "observations.name_id IN (#{names_above_genus}) OR " \
               "observations.vote_cache <= 0"
    end

    # This was built to pass a giant array of name ids, because I believe it's
    # faster than some kind of join.
    # Another way would be to parse_name and check observations.classification
    # on the already initialize_unfiltered list of id's.
    def initialize_by_clade
      # # Although the whole name is passed, it only receives the ID
      # # Seems we have to look it up again (?)
      # name = Name.find(params[:clade])

      # # Avoid inner queries: get these ids directly
      # name_plus_subtaxa = Name.include_subtaxa_of(name)
      # subtaxa_above_genus = name_plus_subtaxa.
      #                       with_rank_above_genus.map(&:id).join(", ")
      # lower_subtaxa = name_plus_subtaxa.
      #                 with_rank_at_or_below_genus.map(&:id).join(", ")

      # # careful... the name may not have lower_subtaxa
      # condition = "observations.name_id IN (#{subtaxa_above_genus})"
      # if lower_subtaxa.present?
      #   condition += " OR (observations.name_id IN (#{lower_subtaxa}) " \
      #                      "AND observations.vote_cache <= 0)"
      # end

      # where << condition

      # Change: just passing the text_name to parse_name
      where << name_in_clade_condition
    end

    def initialize_by_region
      where << location_in_region_condition
    end

    # Some inefficiency here comes from having to parse the name from a string.
    # Write a filtered select/autocomplete that passes the name_id?

    # from content_filter/clade.rb
    def name_in_clade_condition
      val = params[:clade]
      name, rank = parse_name(val)
      if Name.ranks_above_genus.include?(rank)
        "observations.text_name = '#{name}' OR " \
        "observations.classification REGEXP '#{rank}: _#{name}_'"
      else
        "observations.text_name = '#{name}' OR " \
        "observations.text_name REGEXP '^#{name} '"
      end
    end

    def parse_name(val)
      name = Name.best_match(val)
      return [name.text_name, name.rank] if name

      [val, Name.guess_rank(val) || "Genus"]
    end

    # from content_filter/region.rb
    def location_in_region_condition
      val = params[:region]
      val = Location.reverse_name_if_necessary(val)
      expr = make_regexp(query, val)
      "CONCAT(', ', observations.where) #{expr}"
    end

    def make_regexp(query, val)
      if Location.understood_continent?(val)
        vals = Location.countries_in_continent(val).join("|")
        "REGEXP #{query.escape(", (#{vals})$")}"
      else
        "LIKE #{query.escape("%, #{val}")}"
      end
    end
  end
end
