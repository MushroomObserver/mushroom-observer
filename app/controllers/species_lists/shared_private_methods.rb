# frozen_string_literal: true

# private methods shared by SpeciesListsController and subcontrollers
module SpeciesLists
  module SharedPrivateMethods
    ############################################################################
    #
    #  :section: Helpers
    #
    ############################################################################

    def find_species_list!
      SpeciesList.show_includes.safe_find(params[:id].to_s) ||
        flash_error_and_goto_index(SpeciesList, params[:id].to_s)
    end

    def validate_place_name
      if Location.is_unknown?(@species_list.place_name) ||
         @species_list.place_name.blank?
        @species_list.location = Location.unknown
        @species_list.where = nil
      end

      @place_name = @species_list.place_name
      @dubious_where_reasons = []
      unless (@place_name != params[:approved_where]) &&
             @species_list.location_id.nil?
        return
      end

      db_name = Location.user_format(@user, @place_name)
      @dubious_where_reasons = Location.dubious_name?(db_name, true)
    end

    def list_without_underscores
      params.dig(:list, :members).to_s.tr("_", " ").strip_squeeze
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

    def check_if_name_sorter_failed(sorter)
      failed = false

      # Does list have "Name one = Name two" type lines?
      if sorter.has_new_synonyms
        flash_error(:runtime_species_list_create_synonym.t)
        sorter.reset_new_names
        failed = true
      end

      # Are there any unrecognized names?
      if sorter.new_name_strs != []
        if Rails.env.test?
          x = sorter.new_name_strs.map(&:to_s).inspect
          flash_error("Unrecognized names given: #{x}")
        end
        failed = true
      end

      # Are there any ambiguous names?
      unless sorter.only_single_names
        if Rails.env.test?
          x = sorter.multiple_line_strs.map(&:to_s).inspect
          flash_error("Ambiguous names given: #{x}")
        end
        failed = true
      end

      # Are there any deprecated names which haven't been approved?
      if sorter.has_unapproved_deprecated_names
        if Rails.env.test?
          x = sorter.deprecated_names.map(&:display_name).inspect
          flash_error("Found deprecated names: #{x}")
        end
        failed = true
      end

      failed
    end

    def update_redirect_and_flash_notices(create_or_update, sorter = nil)
      if create_or_update == :create
        @species_list.log(:log_species_list_created)
        id = @species_list.id
        flash_notice(:runtime_species_list_create_success.t(id: id))
      else
        @species_list.log(:log_species_list_updated)
        id = @species_list.id
        flash_notice(:runtime_species_list_edit_success.t(id: id))
      end

      update_projects(@species_list, params[:project])
      construct_observations(@species_list, sorter) if sorter

      if @species_list.location_id.nil?
        redirect_to(new_location_path(where: @place_name,
                                      set_species_list: @species_list.id))
      else
        redirect_to(species_list_path(@species_list))
      end
      true
    end

    # Creates observations for names written in
    # Uses the member instance vars, as well as:
    #   params[:chosen_approved_names]    Names from radio boxes.
    def construct_observations(spl, sorter)
      # Put together a list of arguments to use when creating new observations.
      spl_args = init_spl_args(spl)

      # This updates certain observation namings already in the list.  It looks
      # for namings that are deprecated, then replaces them with approved
      # synonyms which the user has chosen via radio boxes in
      # params[:chosen_approved_names].
      update_namings(spl)

      # Add all names from text box into species_list. Creates a new observation
      # for each name.  ("single names" are names that matched a single name
      # uniquely.)
      sorter.single_names.each do |name, timestamp|
        spl_args[:when] = timestamp || spl.when
        spl.construct_observation(name, spl_args)
      end

      spl_args[:when] = spl.when
    end

    def init_spl_args(spl)
      member_args = params[:member] || {}
      member_notes = clean_notes(member_args[:notes])

      {
        created_at: spl.updated_at,
        updated_at: spl.updated_at,
        user: @user,
        projects: spl.projects,
        location: spl.location,
        where: spl.where,
        vote: member_args[:vote],
        notes: member_notes,
        lat: member_args[:lat].to_s,
        lng: member_args[:lng].to_s,
        alt: member_args[:alt].to_s,
        is_collection_location: (member_args[:is_collection_location] == "1"),
        specimen: (member_args[:specimen] == "1")
      }
    end

    def update_namings(spl)
      return unless (chosen_names = params[:chosen_approved_names])

      spl.observations.each do |observation|
        observation.namings.each do |naming|
          # (compensate for gsub in _form_species_lists)
          next unless (alt_name_id = chosen_names[naming.name_id.to_s])

          # Getting here means there is an Observation in the SpeciesList
          # that is currently using a Name that the user has chosen against.
          # The code for updating the Naming has been here for a long time
          # but not covered by tests.  Adding a test revealed a bug where
          # the Observation name was not getting updated.  Should we even
          # be doing this in the write in species UI?  If so,
          # should there be a method on Observation or Naming to
          # do the following?
          alt_name = Name.find(alt_name_id)
          if observation.name == naming.name
            observation.name = alt_name
            observation.save
          end
          naming.name = alt_name
          naming.save
        end
      end
    end

    def clean_notes(notes_in)
      return {} if notes_in.blank?

      notes_out = {}
      notes_in.each do |key, val|
        notes_out[key.to_sym] = val.to_s if val.present?
      end
      notes_out
    end

    def re_render_appropriate_form(create_or_update)
      case create_or_update
      when :create
        render(:new)
      when :update
        render(:edit)
      end
    end

    def init_list_for_clone(clone_id)
      return unless (clone = SpeciesList.safe_find(clone_id))

      create_query(:Observation, species_lists: clone)
      @species_list.when = clone.when
      @species_list.place_name = clone.place_name
      @species_list.location = clone.location
      @species_list.title = clone.title
    end

    def init_name_vars_from_sorter(spl, sorter)
      @new_names = sorter.new_name_strs.uniq.sort
      @multiple_names = sorter.multiple_names.uniq.sort_by(&:search_name)
      @deprecated_names = sorter.deprecated_names.uniq.sort_by(&:search_name)
      @list_members = sorter.all_line_strs.join("\r\n")
      @place_name = spl.place_name
    end

    def init_member_vars_for_reload
      member_params    = params[:member] || {}
      @member_vote     = member_params[:vote].to_s
      # cannot leave @member_notes == nil because view expects a hash
      @member_notes    = member_params[:notes] || Observation.no_notes
      @member_lat      = member_params[:lat].to_s
      @member_lng = member_params[:lng].to_s
      @member_alt = member_params[:alt].to_s
      @member_is_collection_location =
        member_params[:is_collection_location].to_s == "1"
      @member_specimen = member_params[:specimen].to_s == "1"
    end

    def init_project_vars
      @projects = User.current.projects_member(order: :title,
                                               include: { user_group: :users })
      @project_checks = {}
    end

    def init_project_vars_for_create
      init_project_vars
      last_obs = Observation.recent_by_user(@user).last
      return unless last_obs && last_obs.created_at > 1.hour.ago

      last_obs.projects.each { |proj| @project_checks[proj.id] = true }
    end

    def init_project_vars_for_edit(spl)
      init_project_vars
      spl.projects.each do |proj|
        @projects << proj unless @projects.include?(proj)
        @project_checks[proj.id] = true
      end
    end

    def init_project_vars_for_reload(spl)
      init_project_vars
      spl.projects.each do |proj|
        @projects << proj unless @projects.include?(proj)
      end
      @projects.each do |proj|
        @project_checks[proj.id] = params[:project] &&
                                   params[:project]["id_#{proj.id}"] == "1"
      end
    end

    def update_projects(spl, checks)
      return unless checks

      any_changes = false
      Project.where(id: User.current.projects_member.map(&:id)).
        includes(:species_lists).find_each do |project|
          before = spl.projects.include?(project)
          after = checks["id_#{project.id}"] == "1"
          next if before == after

          change_project_species_lists(
            project: project, spl: spl, change: (after ? :add : :remove)
          )
          any_changes = true
        end

      flash_notice(:species_list_show_manage_observations_too.t) if any_changes
    end

    def change_project_species_lists(project:, spl:, change: :add)
      if change == :add
        project.add_species_list(spl)
        flash_notice(:attached_to_project.t(object: :species_list,
                                            project: project.title))
      else
        project.remove_species_list(spl)
        flash_notice(:removed_from_project.t(object: :species_list,
                                             project: project.title))
      end
    end

    def permitted_species_list_args
      ["when(1i)", "when(2i)", "when(3i)", :place_name, :title, :notes]
    end
  end
end
