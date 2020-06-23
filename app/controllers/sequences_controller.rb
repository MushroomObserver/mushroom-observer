# frozen_string_literal: true

#  Controller for nucleotide Sequences
#
#  Actions:
#
#    index_sequence::    List selected sequences, based on current Query.
#    show_sequence::     Display sequence details.
#    create_sequence::   Create new sequence and add to Observation.
#    destroy_sequence::  Destroy sequence.
#    edit_sequence::     Update sequence.
#
class SequencesController < ApplicationController
  before_action :login_required, except: [
    :index,
    :index_sequence,
    :list_sequences, # aliased
    :sequence_search,
    :observation_index,
    :show,
    :show_next,
    :show_prev,
    :show_sequence, # aliased
    :next_sequence, # aliased
    :prev_sequence # aliased
  ]

  def index_sequence
    query = find_or_create_query(:Sequence, by: params[:by])
    show_selected_sequences(query, id: params[:id].to_s, always_index: true)
  end

  def index
    store_location
    query = create_query(:Sequence, :all)
    show_selected_sequences(query)
  end

  alias list_sequences index

  # Display list of Sequences whose text matches a string pattern.
  def sequence_search
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) && (sequence = Sequence.safe_find(pattern))
      redirect_to(sequence_path(sequence.id))
    else
      query = create_query(:Sequence, :pattern_search, pattern: pattern)
      show_selected_sequences(query)
    end
  end

  def observation_index
    store_location
    query = create_query(:Sequence, :for_observation,
                         observation: params[:id].to_s)
    @links = [
      [:show_object.l(type: :observation), observation_path(params[:id])],
      [:show_observation_add_sequence.l, new_sequence_path(id: params[:id])]
    ]
    show_selected_sequences(query, always_index: true)
  end

  def show
    pass_query_params
    store_location
    @sequence = find_or_goto_index(Sequence, params[:id].to_s)
  end

  alias show_sequence show

  def show_next
    redirect_to_next_object(:next, Sequence, params[:id].to_s)
  end

  alias next_sequence show_next

  def show_prev
    redirect_to_next_object(:prev, Sequence, params[:id].to_s)
  end

  alias prev_sequence show_prev

  def new
    store_location
    pass_query_params
    @observation = find_or_goto_index(Observation, params[:id].to_s)
    return unless @observation

    @back_object = @observation
    @sequence = Sequence.new(observation: @observation)
  end

  alias create_sequence new

  def create
    store_location
    pass_query_params
    @observation = find_or_goto_index(Observation, params[:id].to_s)
    return unless @observation

    build_sequence
  end

  def edit
    store_location
    pass_query_params
    @sequence = find_or_goto_index(Sequence, params[:id].to_s)
    return unless @sequence

    figure_out_where_to_go_back_to
    return if check_permission(@sequence) # happy path; render the view

    flash_warning(:permission_denied.t)
    redirect_to observation_path(@sequence.observation_id, q: get_query_param)
  end

  alias edit_sequence edit

  def update
    store_location
    pass_query_params
    @sequence = find_or_goto_index(Sequence, params[:id].to_s)
    return unless @sequence

    figure_out_where_to_go_back_to
    if check_permission(@sequence)
      save_updates
    else
      flash_warning(:permission_denied.t)
      redirect_to(observation_path(@sequence.observation, q: params[:q]))
    end
  end

  def destroy
    pass_query_params
    @sequence = find_or_goto_index(Sequence, params[:id].to_s)
    return unless @sequence

    figure_out_where_to_go_back_to
    if check_permission(@sequence)
      @sequence.destroy
      flash_notice(:runtime_destroyed_id.t(type: Sequence, value: params[:id]))
    else
      flash_warning(:permission_denied.t)
    end

    if @back == "index"
      redirect_to(sequences_index_sequence_path(q: get_query_param))
    else
      # TODO: NIMMO is @back_object here always an observation? Check
      # Answer: Currently yes. JDC 2020-06-21
      redirect_to(helpers.object_path(@back_object, q: get_query_param))
    end
  end

  alias destroy_sequence destroy

  ##############################################################################

  private

  def build_sequence
    @sequence = @observation.sequences.new
    @sequence.attributes = whitelisted_sequence_params
    @sequence.user = @user
    if @sequence.save
      flash_notice(:runtime_sequence_success.t(id: @sequence.id))
      redirect_to observation_path(@observation.id, q: get_query_param)
    else
      flash_object_errors(@sequence)
    end
  end

  def save_updates
    @sequence.attributes = whitelisted_sequence_params
    if @sequence.save
      flash_notice(:runtime_sequence_success.t(id: @sequence.id))
      redirect_to(helpers.object_path(@back_object, q: get_query_param))
    else
      flash_object_errors(@sequence)
    end
  end

  def figure_out_where_to_go_back_to
    @back = params[:back]
    @back_object = @back == "show" ? @sequence : @sequence.observation
  end

  def show_selected_sequences(query, args = {})
    args = {
      action: :index,
      letters: "sequences.locus",
      num_per_page: 50
    }.merge(args)
    @links ||= []
    args[:sorting_links] = sequence_index_sorts
    show_index_of_objects(query, args)
  end

  def sequence_index_sorts
    [
      ["created_at",  :sort_by_created_at.t],
      ["updated_at",  :sort_by_updated_at.t],
      ["user",        :USER.t],
      ["observation", :OBSERVATION.t]
    ]
  end

  def whitelisted_sequence_params
    params[:sequence].permit(
      :archive, :accession, :bases, :locus, :notes, :back
    )
  end
end
