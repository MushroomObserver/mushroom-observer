# frozen_string_literal: true

class API2
  # API for Location
  class LocationAPI < ModelAPI
    self.model = Location

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :comments
    ]

    def query_params
      n, s, e, w = parse_bounding_box!
      {
        where: sql_id_condition,
        created_at: parse_range(:time, :created_at),
        updated_at: parse_range(:time, :updated_at),
        users: parse_array(:user, :user, help: :first_user),
        north: n,
        south: s,
        east: e,
        west: w
      }
    end

    def create_params
      {
        display_name: parse(:string, :name, limit: 1024, help: :postal),
        north: parse(:latitude, :north),
        south: parse(:longitude, :south),
        east: parse(:longitude, :east),
        west: parse(:longitude, :west),
        high: parse(:altitude, :high),
        low: parse(:altitude, :low),
        notes: parse(:string, :notes),
        user: @user
      }
    end

    def update_params
      {
        display_name: parse(:string, :set_name, limit: 1024, not_blank: true,
                                                help: :postal),
        north: parse(:latitude, :set_north),
        south: parse(:longitude, :set_south),
        east: parse(:longitude, :set_east),
        west: parse(:longitude, :set_west),
        high: parse(:altitude, :set_high),
        low: parse(:altitude, :set_low),
        notes: parse(:string, :set_notes)
      }
    end

    def validate_create_params!(params)
      name = params[:display_name]
      raise(MissingParameter.new(:name))  unless params[:display_name]
      raise(MissingParameter.new(:north)) unless params[:north]
      raise(MissingParameter.new(:south)) unless params[:south]
      raise(MissingParameter.new(:east))  unless params[:east]
      raise(MissingParameter.new(:west))  unless params[:west]

      make_sure_location_doesnt_exist!(name)
      make_sure_location_isnt_dubious!(name)
    end

    def validate_update_params!(params)
      name = params[:display_name]
      make_sure_location_doesnt_exist!(name)
      make_sure_location_isnt_dubious!(name)
      make_sure_not_setting_name_of_multiple_locations!
      raise(MissingSetParameters.new) if params.empty?
    end

    def delete
      raise(NoMethodForAction.new("DELETE", action))
    end

    # Our restrictions on edit permissions for the API are much more strict
    # than on the website.  Revoke permission if anyone other than the creator
    # owns any attached objects: location versions, descriptions, observations,
    # species lists, users (i.e. profile location), or herbaria.
    def must_have_edit_permission!(loc)
      must_be_creator!(loc)
      must_be_only_editor!(loc)
      must_own_all_descriptions!(loc)
      must_own_all_observations!(loc)
      must_own_all_species_lists!(loc)
      must_not_be_another_users_profile_location!(loc)
      must_not_have_any_herbaria!(loc)
    end

    ############################################################################

    private

    def must_be_creator!(loc)
      return if loc.user == @user

      raise(MustBeCreator.new(:location))
    end

    def must_be_only_editor!(loc)
      return unless loc.versions.any? { |x| x.user_id != @user.id }

      raise(MustBeOnlyEditor.new(:location))
    end

    def must_own_all_descriptions!(loc)
      return unless loc.descriptions.any? { |x| x.user != @user }

      raise(MustOwnAllDescriptions.new(:location))
    end

    def must_own_all_observations!(loc)
      return unless loc.observations.any? { |x| x.user != @user }

      raise(MustOwnAllObservations.new(:location))
    end

    def must_own_all_species_lists!(loc)
      return unless loc.species_lists.any? { |x| x.user != @user }

      raise(MustOwnAllSpeciesLists.new(:location))
    end

    def must_not_be_another_users_profile_location!(loc)
      return unless loc.users.any? { |x| x != @user }

      raise(AnotherUsersProfileLocation.new)
    end

    def must_not_have_any_herbaria!(loc)
      return unless loc.herbaria.any?

      raise(MustNotHaveAnyHerbaria.new)
    end

    def make_sure_location_doesnt_exist!(name)
      return unless Location.find_by_name_or_reverse_name(name)

      raise(LocationAlreadyExists.new(name))
    end

    def make_sure_not_setting_name_of_multiple_locations!
      raise(TryingToSetMultipleLocationsToSameName.new) \
        if query.num_results > 1
    end
  end
end
