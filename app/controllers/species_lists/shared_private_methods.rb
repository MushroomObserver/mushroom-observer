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

    def init_name_vars_from_sorter(spl, sorter)
      @new_names = sorter.new_name_strs.uniq.sort
      @multiple_names = names_with_other_authors(sorter)
      @deprecated_names = sorter.deprecated_names.uniq.sort_by(&:search_name)
      @list_members = sorter.all_line_strs.join("\r\n")
      @place_name = spl.place_name
    end

    def names_with_other_authors(sorter)
      names = sorter.multiple_names.uniq.sort_by(&:search_name)

      names.map do |name|
        [name, name.other_authors.includes([:observations])]
      end
    end

    def init_project_vars
      @projects = @user.projects_member(order: :title,
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
  end
end
