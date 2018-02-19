module Query
  module Initializers
    # Help initialize "of_name" queries.
    module OfName
      def of_name_parameter_declarations
        {
          name:          :name,
          synonyms?:     { string: [:no, :all, :exclusive] },
          nonconsensus?: { string: [:no, :all, :exclusive, :other_taxa] }
        }
      end

      def give_parameter_defaults
        params[:synonyms]     ||= :no
        params[:nonconsensus] ||= :no
      end

      def target_names
        name = get_cached_parameter_instance(:name)
        return [name] if name
        name = params[:name]
        if name.is_a?(Integer) || name.match(/^\d+$/)
          [Name.find(name.to_i)]
        else
          names = Name.where(search_name: name)
          names = Name.where(text_name: name) if names.empty?
          names
        end
      end

      def choose_a_title(names, with_observations = false)
        choose_a_title_tag(with_observations)
        choose_a_title_args(names)
      end

      def choose_a_title_tag(with_observations)
        tag = "of_name"
        tag = "of_name_synonym"          if params[:synonyms] != :no
        tag = "of_name_nonconsensus"     if params[:nonconsensus] != :no
        tag = "with_observations_#{tag}" if with_observations
        self.title_tag = :"query_title_#{tag}"
      end

      def choose_a_title_args(names)
        title_args[:name] = params[:name]
        title_args[:name] = names.first.display_name if names.length == 1
      end

      def add_name_conditions(names)
        id_set = corresponding_name_id_set(names)
        if params[:nonconsensus] == :no
          add_name_conditions_consensus_only(id_set)
        elsif params[:nonconsensus] == :all
          add_name_conditions_all_namings(id_set)
        elsif params[:nonconsensus] == :exclusive
          add_name_conditions_just_losers(id_set)
        elsif params[:nonconsensus] == :other_taxa
          add_name_conditions_other_taxa(
            included_naming: names.first.id,
            excluded_names: corresponding_name_id_set(names)
          )
        end
      end

      def add_name_conditions_consensus_only(id_set)
        where << "observations.name_id IN (#{id_set}) AND " \
                 "COALESCE(observations.vote_cache,0) >= 0"
        self.order = "COALESCE(observations.vote_cache,0) DESC, " \
                     "observations.when DESC"
      end

      def add_name_conditions_all_namings(id_set)
        where << "namings.name_id IN (#{id_set})"
        self.order = "COALESCE(namings.vote_cache,0) DESC, " \
                     "observations.when DESC"
        add_join_to_observations(:namings)
      end

      def add_name_conditions_just_losers(id_set)
        where << "namings.name_id IN (#{id_set}) AND " \
                 "(observations.name_id NOT IN (#{id_set}) OR " \
                 "COALESCE(observations.vote_cache,0) < 0)"
        self.order = "COALESCE(namings.vote_cache,0) DESC, " \
                     "observations.when DESC"
        add_join_to_observations(:namings)
      end

      def add_name_conditions_other_taxa(included_naming:, excluded_names:)
        where << "namings.name_id IN (#{included_naming}) AND " \
                 "(observations.name_id NOT IN (#{excluded_names}) OR " \
                 "COALESCE(observations.vote_cache,0) < 0)"
        self.order = "COALESCE(namings.vote_cache,0) DESC, " \
                     "observations.when DESC"
        add_join_to_observations(:namings)
      end

      def corresponding_name_id_set(names)
        name_ids = corresponding_name_ids(names)
        clean_id_set(name_ids.uniq)
      end

      def corresponding_name_ids(names)
        if params[:synonyms] == :no
          just_names(names)
        elsif params[:synonyms] == :all
          names_and_synonyms(names)
        elsif params[:synonyms] == :exclusive
          just_synonyms(names)
        end
      end

      def just_names(names)
        names.map(&:id) + names.map(&:misspelling_ids).flatten
      end

      def names_and_synonyms(names)
        names.map(&:synonym_ids).flatten
      end

      def just_synonyms(names)
        names.map(&:synonym_ids).flatten -
          names.map(&:id) -
          names.map(&:misspelling_ids).flatten
      end
    end
  end
end
