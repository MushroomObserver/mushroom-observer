# frozen_string_literal: true

module Query
  # methods for initializing Queries for Observations Needing Identification
  class ObservationNeedsNaming < Query::ObservationBase
    def parameter_declarations
      super.merge(
        in_clade?: :string,
        in_region?: :string # ,
        # by_user?: :string
      )
    end

    # 15x faster to use AR scope to assemble the IDs vs SQL SELECT DISTINCT!
    def initialize_flavor
      user = User.current_id
      where << Observation.needs_naming_and_not_reviewed_by_user(user).to_sql.
               gsub(/^.*?WHERE/, "")

      where << name_in_clade_condition if params[:in_clade]
      where << location_in_region_condition if params[:in_region]
      super
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

    # The tricky thing here is, without the user.id being the value passed in
    # params[:filter][:term], we're hunting for a user from a string like
    # "Name <name>". Better to have the id as the value!
    # Below uses the method in query/initializers/advanced_search to get a
    # string but is expensive. Something like
    # joins(:users).where((User[:login] + User[:name]).matches(str))
    # def by_user_condition
    #   user = params[:by_user].to_s.gsub(/ *<[^<>]*>/, "")
    # end
  end
end
