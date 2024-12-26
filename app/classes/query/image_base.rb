# frozen_string_literal: true

module Query
  # base class for all flavors of Query which return Images
  class ImageBase < Query::Base
    include Query::Initializers::Images
    include Query::Initializers::Names
    include Query::Initializers::AdvancedSearch

    def model
      Image
    end

    def parameter_declarations
      super.merge(images_only_parameter_declarations).
        merge(names_parameter_declarations).
        merge(advanced_search_parameter_declarations)
    end

    # rubocop:disable Metrics/AbcSize
    def initialize_flavor
      super
      unless is_a?(Query::ImageWithObservations)
        add_ids_condition
        add_img_inside_observation_conditions
        add_owner_and_time_stamp_conditions
        add_by_user_condition
        add_date_condition("images.when", params[:date])
        add_join(:observation_images) if params[:with_observation]
        initialize_img_notes_parameters
        initialize_img_association_parameters
      end
      add_pattern_condition
      add_img_advanced_search_conditions
      initialize_name_parameters(:observation_images, :observations)
      initialize_img_record_parameters
      initialize_img_vote_parameters
    end
    # rubocop:enable Metrics/AbcSize

    def add_pattern_condition
      return if params[:pattern].blank?

      add_join(:observation_images, :observations)
      add_join(:observations, :locations!)
      add_join(:observations, :names)
      super
    end

    def search_fields
      "CONCAT(" \
        "names.search_name," \
        "COALESCE(images.original_name,'')," \
        "COALESCE(images.copyright_holder,'')," \
        "COALESCE(images.notes,'')," \
        "observations.where" \
        ")"
    end

    def add_join_to_names
      add_join(:observations, :names)
    end

    def add_join_to_users
      add_join(:observations, :users)
    end

    def add_join_to_locations
      add_join(:observations, :locations!)
    end

    def self.default_order
      "created_at"
    end
  end
end
