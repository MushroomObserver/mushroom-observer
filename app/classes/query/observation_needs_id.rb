# frozen_string_literal: true

module Query
  # methods for initializing Queries for Observations Needing Identification
  class ObservationNeedsId < Query::ObservationBase
    def parameter_declarations
      super.merge(
        in_clade?: :string,
        in_region?: :string
      )
    end

    # 15x faster to use the scope to assemble the IDs vs SQL SELECT DISTINCT!
    def initialize_flavor
      user = User.current_id
      # voted = Observation.with_vote_by_user(user).map(&:id).join(", ")
      # reviewed = Observation.reviewed_by_user(user).map(&:id).join(", ")

      # where << "observations.id NOT IN (#{voted})" # if voted.present?
      # where << "observations.id NOT IN (#{reviewed})" # if reviewed.present?
      needs_id = Observation.needs_id_for_user(user).map(&:id).join(", ")
      where << "observations.id IN (#{needs_id})" if needs_id.present?

      where << unspecific_or_unconfident_condition
      where << name_in_clade_condition if params[:in_clade]
      where << location_in_region_condition if params[:in_region]
      # binding.break
      super
    end

    # def default_order
    #   "rss_log"
    # end

    # The basic query: any namings with low confidence, or names above genus
    def unspecific_or_unconfident_condition
      names_above_genus = Name.with_rank_above_genus.map(&:id).join(", ")

      "observations.name_id IN (#{names_above_genus}) OR " \
      "observations.vote_cache <= 0"
    end

    # from content_filter/clade.rb
    # parse_name and check the already initialize_unfiltered list of
    # observations against observations.classification.
    # Some inefficiency here comes from having to parse the name from a string.
    # TODO: Write a filtered select/autocomplete that passes the name_id as val
    def name_in_clade_condition
      val = params[:in_clade]
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

    # from content_filter/region.rb, but simpler.
    # includes region itself (i.e., no comma before region in 2nd regex)
    def location_in_region_condition
      region = params[:in_region]
      region = Location.reverse_name_if_necessary(region)

      if Location.understood_continent?(region)
        countries = Location.countries_in_continent(region).join("|")
        "observations.where REGEXP #{escape(", (#{countries})$")}"
      else
        "observations.where LIKE #{escape("%#{region}")}"
      end
    end
  end
end
