# frozen_string_literal: true

# see app/controllers/species_lists_controller.rb
class SpeciesListsController

  ##############################################################################
  #
  #  :section: Manage Observations
  #
  ##############################################################################

  # TODO: NIMMO is this another REST controller here?
  # SpeciesList::ObservationsController

  def add_remove_observations # :prefetch: :norobots:
    pass_query_params
    @id = params[:species_list].to_s
    @query = find_obs_query_or_redirect
  end

  def post_add_remove_observations # :prefetch: :norobots:
    pass_query_params
    id = params[:species_list].to_s
    @species_list = find_list_or_reload_form(id)
    return unless @species_list

    query = find_obs_query_or_redirect(@species_list)
    return unless query

    do_add_remove_observations(@species_list, query)
    redirect_to @species_list
  end

  def find_obs_query_or_redirect(@species_list = nil)
    query = find_query(:Observation)
    return query if query

    flash_error(:species_list_add_remove_no_query.t)
    if @species_list
      redirect_to @species_list
    else
      redirect_to action: :index
    end
    nil
  end

  def find_list_or_reload_form(id)
    list = lookup_species_list_by_id_or_name(id)
    return list if list

    flash_error(:species_list_add_remove_bad_name.t(name: id.inspect))
    redirect_to(
      add_query_param(
        action: :add_remove_observations,
        species_list: id
      )
    )
    nil
  end

  def lookup_species_list_by_id_or_name(str)
    if /^\d+$/.match?(str)
      SpeciesList.safe_find(str)
    else
      SpeciesList.find_by_title(str)
    end
  end

  def do_add_remove_observations(spl, query)
    return unless check_permission!(spl)

    if params[:commit] == :ADD.l
      do_add_observations(spl, query)
    elsif params[:commit] == :REMOVE.l
      do_remove_observations(spl, query)
    else
      flash_error("Invalid mode: #{params[:commit].inspect}")
    end
  end

  def do_add_observations(species_list, query)
    ids = query.result_ids - species_list.observation_ids
    return if ids.empty?

    # This is apparently extremely inefficient.  Danny says it times out for
    # large species_lists, such as "Neotropical Fungi".
    # species_list.observation_ids += ids
    Observation.connection.insert(%(
      INSERT INTO observations_species_lists
        (observation_id, species_list_id)
      VALUES
        #{ids.map { |id| "(#{id},#{species_list.id})" }.join(",")}
    ))
    flash_notice(:species_list_add_remove_add_success.t(num: ids.length))
  end

  def do_remove_observations(species_list, query)
    ids = query.result_ids & species_list.observation_ids
    return if ids.empty?

    species_list.observation_ids -= ids
    flash_notice(:species_list_add_remove_remove_success.t(num: ids.length))
  end

  # Form to let user add/remove an observation from one of their species lists.
  def manage_species_lists # :prefetch: :norobots:
    @observation = find_or_goto_index(Observation, params[:id].to_s)
    @all_lists = @user.all_editable_species_lists
  end

  # Used by manage_species_lists.
  def remove_observation_from_species_list # :norobots:
    @species_list = find_or_goto_index(SpeciesList, params[:species_list])
    return unless @species_list

    @observation = find_or_goto_index(Observation, params[:observation])
    return unless @observation

    if check_permission!(@species_list)
      @species_list.remove_observation(@observation)
      flash_notice(:runtime_species_list_remove_observation_success.
        t(name: @species_list.unique_format_name, id: @observation.id))
      redirect_to action: :manage_species_lists, id: @observation.id
    else
      redirect_to @species_list.id
    end
  end

  # Used by manage_species_lists.
  def add_observation_to_species_list # :norobots:
    @species_list = find_or_goto_index(SpeciesList, params[:species_list])
    return unless @species_list

    @observation = find_or_goto_index(Observation, params[:observation])
    return unless @observation

    if check_permission!(@species_list)
      @species_list.add_observation(@observation)
      flash_notice(:runtime_species_list_add_observation_success.
        t(name: @species_list.unique_format_name, id: @observation.id))
      redirect_to action: :manage_species_lists, id: @observation.id
    else
      redirect_to @species_list
    end
  end

  # Bulk-edit observations (at least the ones editable by this user) in a (any)
  # species list.
  # :norobots:
  def bulk_editor
    @species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
    return unless @species_list

    @query = create_query(
      :Observation,
      :in_species_list,
      by: :id,
      species_list: @species_list,
      where: "observations.user_id = #{@user.id}"
    )
    @pages = paginate_numbers(:page, 100)
    @observations = @query.paginate(
      @pages, include: [:comments, :images, :location, namings: :votes]
    )
    @observation = {}
    @votes = {}
    @observations.each do |obs|
      @observation[obs.id] = obs
      vote = begin
               obs.consensus_naming.users_vote(@user)
             rescue StandardError
               nil
             end
      @votes[obs.id] = vote || Vote.new
    end
    @no_vote = Vote.new
    @no_vote.value = 0
    if @observation.empty?
      flash_error(:species_list_bulk_editor_you_own_no_observations.t)
      redirect_to(
        action: :show,
        id: @species_list.id
      )
    elsif request.method == "POST"
      updates = 0
      stay_on_page = false
      @observations.each do |obs|
        args = begin
                 params[:observation][obs.id.to_s] || {}
               rescue StandardError
                 {}
               end
        any_changes = false
        old_vote = begin
                     @votes[obs.id].value
                   rescue StandardError
                     0
                   end
        if !args[:value].nil? && args[:value].to_s != old_vote.to_s
          if obs.namings.empty?
            obs.namings.create!(
              user: @user,
              name_id: obs.name_id
            )
          end
          if (naming = obs.consensus_naming)
            obs.change_vote(
              naming,
              args[:value].to_i,
              @user
            )
            any_changes = true
            @votes[obs.id].value = args[:value]
          else
            flash_warning(
              :species_list_bulk_editor_ambiguous_namings.
                t(id: obs.id, name: obs.name.display_name.t)
            )
          end
        end
        [
          :when_str,
          :place_name,
          :other_notes,
          :lat,
          :long,
          :alt,
          :is_collection_location,
          :specimen
        ].each do |method|
          next if args[method].nil?

          old_val = obs.send(method)
          old_val = old_val.to_s if [:lat, :long, :alt].member?(method)
          new_val = bulk_editor_new_val(method, args[method])
          if old_val != new_val
            obs.send("#{method}=", new_val)
            any_changes = true
          end
        end
        if any_changes
          if obs.save
            updates += 1
          else
            flash_error("") if stay_on_page
            flash_error("#{:Observation.t} ##{obs.id}:")
            flash_object_errors(obs)
            stay_on_page = true
          end
        end
      end
      return if stay_on_page

      if updates.zero?
        flash_warning(:runtime_no_changes.t)
      else
        flash_notice(:species_list_bulk_editor_success.t(n: updates))
      end

      redirect_to @species_list
    end
  end

end
