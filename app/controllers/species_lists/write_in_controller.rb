# frozen_string_literal: true

module SpeciesLists
  class WriteInController < ApplicationController
    before_action :login_required

    def new
      @species_list = SpeciesList.find(params[:id])
      init_member_vars_for_create
    end

    def create
      @species_list = SpeciesList.find(params[:id])
      if check_permission!(@species_list)
        process_write_in_list(:create)
      else
        redirect_to(species_list_path(@species_list))
      end
    end

    include SpeciesLists::SharedPrivateMethods # shared private methods

    private

    def init_member_vars_for_create
      @member_vote = Vote.maximum_vote
      @member_notes_parts = @species_list.form_notes_parts(@user)
      @member_notes = @member_notes_parts.each_with_object({}) do |part, h|
        h[part.to_sym] = ""
      end
      @member_lat = nil
      @member_lng = nil
      @member_alt = nil
      @member_is_collection_location = true
      @member_specimen = false
    end

    # Validate list of names, and if successful, create observations.
    # Parameters involved in name list validation:
    #   params[:list][:members]               String user typed in big text area
    #                                         on right side (strip_squozen)
    #   params[:approved_names]               New names from prev post.
    #   params[:approved_deprecated_names]    Deprecated names from prev post.
    #   params[:chosen_multiple_names][name]  Radios choosing ambiguous names.
    #   params[:chosen_approved_names][name]  Radios for accepted names.
    #     (Both the last two radio boxes are hashes with:
    #       key: ambiguous name as typed with nonalphas changed to underscores,
    #       val: id of name user has chosen (via radio boxes in feedback)
    # Bullet:
    # https://blog.appsignal.com/2018/06/19/activerecords-counter-cache.html
    def process_write_in_list(create_or_update)
      redirected = false

      # Update the timestamps/user/when/where/title/notes fields.
      # init_basic_species_list_fields(create_or_update)

      # Validate place name.
      validate_place_name

      list = list_without_underscores

      # Make sure all the names (that have been approved) exist.
      construct_approved_names(list, params[:approved_names])

      # Initialize NameSorter and give it all the information.
      sorter = init_name_sorter(list)

      # Now let us count all the ways in which NameSorter can fail...
      failed = check_if_name_sorter_failed(sorter)

      # Okay, at this point we've apparently validated the new list of names.
      # Save the OTHER changes to the species_list, then let this other method
      # (construct_observations) create the observations.  This always succeeds,
      # so we can redirect to show_species_list (or chain to create location).
      if !failed && @dubious_where_reasons == []
        redirected = create_observations(sorter)
      end

      return if redirected

      # Failed to create due to synonyms, unrecognized names, etc.
      init_name_vars_from_sorter(@species_list, sorter)
      init_member_vars_for_reload
      init_project_vars_for_reload(@species_list)
      re_render_appropriate_form(create_or_update)
    end

    def create_observations(sorter)
      return unless sorter

      # Put together a list of arguments to use when creating new observations.
      spl = @species_list
      spl_args = init_spl_args(spl)
      if @place_name
        spl_args[:where] = @place_name
        spl_args[:location] = Location.find_by_name_or_reverse_name(@place_name)
      end

      update_namings(spl)

      # Add all names from text box into species_list. Creates a new observation
      # for each name.  ("single names" are names that matched a single name
      # uniquely.)
      sorter.single_names.each do |name, timestamp|
        spl_args[:when] = timestamp || spl.when
        spl.construct_observation(name, spl_args)
      end
      redirect_to(species_list_path(spl))
    end

    def validate_place_name
      @place_name = params[:place_name] || @species_list.place_name
      @dubious_where_reasons = []
      return if @place_name == params[:approved_where]

      db_name = Location.user_format(@user, @place_name)
      @dubious_where_reasons = Location.dubious_name?(db_name, true)
    end
  end
end
