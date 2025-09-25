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
      if permission!(@species_list)
        process_write_in_list
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
    def process_write_in_list
      redirected = false

      # Validate place name.
      validate_place_name

      list = list_without_underscores

      # Make sure all the names (that have been approved) exist.
      construct_approved_names(list, params[:approved_names])

      # Initialize NameSorter and give it all the information.
      sorter = init_name_sorter(list)

      # Now let us count all the ways in which NameSorter can fail...
      failed = check_if_name_sorter_failed(sorter)

      if !failed && @dubious_where_reasons == []
        redirected = create_observations(sorter)
      end

      return if redirected

      # Failed to create due to synonyms, unrecognized names, etc.
      init_name_vars_from_sorter(@species_list, sorter)
      init_member_vars_for_reload
      init_project_vars_for_reload(@species_list)
      render(:new)
    end

    def list_without_underscores
      params.dig(:list, :members).to_s.tr("_", " ").strip_squeeze
    end

    def check_if_name_sorter_failed(sorter)
      result = new_synonyms?(sorter)
      result = unrecognized_names?(sorter) || result
      result = ambiguous_names?(sorter) || result
      unapproved_deprecated_names?(sorter) || result
    end

    def new_synonyms?(sorter)
      if sorter.has_new_synonyms
        flash_error(:runtime_species_list_create_synonym.t)
        sorter.reset_new_names
        true
      else
        false
      end
    end

    def unrecognized_names?(sorter)
      if sorter.new_name_strs == []
        false
      else
        if Rails.env.test?
          x = sorter.new_name_strs.map(&:to_s).inspect
          flash_error("Unrecognized names given: #{x}")
        end
        true
      end
    end

    def ambiguous_names?(sorter)
      if sorter.only_single_names
        false
      else
        if Rails.env.test?
          x = sorter.multiple_line_strs.map(&:to_s).inspect
          flash_error("Ambiguous names given: #{x}")
        end
        true
      end
    end

    def unapproved_deprecated_names?(sorter)
      if sorter.has_unapproved_deprecated_names
        if Rails.env.test?
          x = sorter.deprecated_names.map(&:display_name).inspect
          flash_error("Found deprecated names: #{x}")
        end
        true
      else
        false
      end
    end

    def init_name_sorter(list)
      sorter = NameSorter.new
      sorter.add_chosen_names(params[:chosen_multiple_names])
      sorter.add_chosen_names(params[:chosen_approved_names])
      sorter.add_approved_deprecated_names(params[:approved_deprecated_names])
      sorter.check_for_deprecated_names(@species_list.names) if @species_list.id
      sorter.sort_names(@user, list)
      sorter
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

    def init_member_vars_for_reload
      member_params = params[:member] || {}
      @member_vote = member_params[:vote].to_s
      @member_lat = member_params[:lat].to_s
      @member_lng = member_params[:lng].to_s
      @member_alt = member_params[:alt].to_s
      calculated_member_vars_for_reload(member_params)
    end

    def calculated_member_vars_for_reload(member_params)
      # cannot leave @member_notes == nil because view expects a hash
      @member_notes = member_params[:notes] || Observation.no_notes
      @member_is_collection_location =
        member_params[:is_collection_location].to_s == "1"
      @member_specimen = member_params[:specimen].to_s == "1"
    end
  end
end
