# frozen_string_literal: true

module Query
  module Initializers
    # initializing methods inherited by all Query's for Names
    module ObservationQueryDescriptions
      def with_observations_query_description
        return nil unless (description = observation_query_description)

        :query_title_with_observations_filtered.t(type: model.type_tag,
                                                  subtitle: description)
      end

      def observation_query_description
        return nil unless (params.keys - [:by]).any?

        # For now just deal with simple cases which correspond more or less
        # to the old flavors.
        args = [:herbaria, :locations, :names, :projects, :project_lists,
                :species_lists, :users].reject { |arg| params[arg].empty? }
        if args.length == 1
          send("title_for_#{args.first}")
        else
          :query_title_all_filtered.t(type: :observation)
        end
      end

      private

      def title_for_herbaria
        str = map_join_and_truncate(:herbaria, Herbarium, :name)
        :query_title_in_herbarium.t(type: :observation, herbarium: str)
      end

      def title_for_locations
        str = map_join_and_truncate(:locations, Location, :display_name)
        :query_title_at_location.t(type: :observation, location: str)
      end

      def title_for_names
        str = map_join_and_truncate(:names, Name, :text_name)
        :query_title_of_name.t(type: :observation, name: str)
      end

      def title_for_projects
        str = map_join_and_truncate(:projects, Project, :title)
        :query_title_for_project.t(type: :observation, project: str)
      end

      def title_for_project_lists
        str = map_join_and_truncate(:project_lists, Project, :title)
        :query_title_in_lists_for_project.t(type: :observation, project: str)
      end

      def title_for_species_lists
        str = map_join_and_truncate(:species_lists, SpeciesList, :title)
        :query_title_in_species_list.t(type: :observation, species_list: str)
      end

      def title_for_users
        str = map_join_and_truncate(:users, User, :login)
        :query_title_for_user.t(type: :observation, user: str)
      end

      def map_join_and_truncate(arg, model, method)
        str = params[arg].map do |val|
          # Integer(val) throws ArgumentError if val is not an integer.
          # This is the most efficient way to test if a string is an
          # integer according to a very thorough and detailed blog post!
          model.find(Integer(val)).send(method)
        rescue ArgumentError # rubocop:disable Layout/RescueEnsureAlignment
          val
        end.join(", ")
        str = "#{str[0...97]}..." if str.length > 100
        str
      end
    end
  end
end
