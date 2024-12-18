# frozen_string_literal: true

class Query::LocationBase < Query::Base
  include Query::Initializers::ContentFilters

  def model
    Location
  end

  def parameter_declarations
    super.merge(
      created_at?: [:time],
      updated_at?: [:time],
      ids?: [Location],
      by_user?: User,
      by_editor?: User,
      users?: [User],
      north?: :float,
      south?: :float,
      east?: :float,
      west?: :float
      # pattern?: :string,
      # regexp?: :string
    ).merge(content_filter_parameter_declarations(Location))
  end

  def initialize_flavor
    unless is_a?(Query::LocationWithObservations) ||
           is_a?(Query::LocationWithDescriptions)
      add_ids_condition("locations")
      add_owner_and_time_stamp_conditions("locations")
      add_by_user_condition("locations")
      add_by_editor_condition
    end
    add_bounding_box_conditions_for_locations
    # add_pattern_condition
    # add_regexp_condition
    initialize_content_filters(Location)
    super
  end

  def add_by_editor_condition
    return unless params[:by_editor]

    user = find_cached_parameter_instance(User, :by_editor)
    @title_tag = :query_title_by_editor.t(type: :location,
                                          user: user.legal_name)
    @title_args[:user] = user.legal_name
    version_table = :location_versions
    add_join(version_table)
    where << "#{version_table}.user_id = '#{user.id}'"
    where << "locations.user_id != '#{user.id}'"
  end

  # def add_pattern_condition
  #   return if params[:pattern].blank?

  #   add_join(:"location_descriptions.default!")
  #   super
  # end

  # def add_regexp_condition
  #   return if params[:regexp].blank?

  #   @title_tag = :query_title_regexp_search
  #   regexp = escape(params[:regexp].to_s.strip_squeeze)
  #   where << "locations.name REGEXP #{regexp}"
  # end

  # def search_fields
  #   "CONCAT(" \
  #     "locations.name," \
  #     "#{LocationDescription.all_note_fields.map do |x|
  #          "COALESCE(location_descriptions.#{x},'')"
  #        end.join(",")}" \
  #   ")"
  # end

  def self.default_order
    "name"
  end
end
