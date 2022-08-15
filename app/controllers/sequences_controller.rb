# frozen_string_literal: true

#  Controller for nucleotide Sequences
#
#  Actions:
#
#    create::   Create new sequence and add to Observation
#    destroy::  Destroy sequence
#    edit::     Show form to edit a Sequence
#    new::      Show form to create new Sequence for an Observation
#    index::    List selected Sequences, based on index flavor and current Query
#    show::     Display Sequence details
#    update::   Update a Sequence
#
# Table: (updated 2022-08-07)
# legacy Sequence action (method)   updated Sequences action (method)
# --------------------------------  ---------------------------------
# create_sequence (get)             new (get)
# *create_sequence (post)           create (post)
# destroy_sequence (delete)         destroy (delete)
# edit_sequence (get)               edit (get)
# *edit_sequence (post)             update (patch)
# index_sequence (get)              index (get) -- lists query results
# list_sequences (get)              index (get, flavor: all) -- all Sequences
# *next_sequence (get)              show { flow: :next } (get))
# *prev_sequence (get)              show { flow: :prev } (get)
# observation_index (get)           index (get, flavor: observation)
#                                   -- list Sequences for one Observation
# sequence_search (get)             index (get, pattern: present)
# show_sequence (get)               show (get)
# * == legacy action is not redirected
# Cf. https://tinyurl.com/ynapvpt7
#
class SequencesController < ApplicationController
  before_action :login_required
  before_action :store_location, only: [:create, :edit, :new, :show, :update]
  before_action :pass_query_params, only: [
    :create, :destroy, :edit, :new, :show, :update
  ]

  ################# Actions that show data without modifying it

  # display a list of Sequences, depending on flavor & params
  # Examples:
  #  https://mushroomobserver.org/sequences?flavor=observation&id=205345
  #    => displays a list of sequences for Observation 205345
  #  https://mushroomobserver.org/sequences?flavor=all
  #    => displays a list of all sequences in MO
  #  https://mushroomobserver.org/sequences?pattern=LSU
  #    => displays a list of all sequences that include "LSU"
  #
  def index
    return patterned_index if params[:pattern].present?

    case params[:flavor]
    when "all"
      index_all
    when "observation"
      index_observation
    else
      query = find_or_create_query(:Sequence, by: params[:by])
      show_selected_sequences(query, id: params[:id].to_s, always_index: true)
    end
  end

  def show
    case params[:flow]
    when "next"
      redirect_to_next_object(:next, Sequence, params[:id]) and return
    when "prev"
      redirect_to_next_object(:prev, Sequence, params[:id]) and return
    end

    @sequence = find_or_goto_index(Sequence, params[:id].to_s)
  end

  ################# Actions that modify data

  def new
    # Observation.id is passed as a query param (rather than route :id param)
    # in order to give :id param a consistent meaning (the sequence id)
    # in this controller and in order to avoid an extra, non-standard route
    return if params[:obs_id].blank?

    @observation = find_or_goto_index(Observation, params[:obs_id].to_s)
    return unless @observation

    @sequence = Sequence.new
  end

  def create
    @observation = find_or_goto_index(Observation, params[:obs_id].to_s)
    return unless @observation

    build_sequence
  end

  def edit
    @sequence = find_or_goto_index(Sequence, params[:id].to_s)
    return unless @sequence

    figure_out_where_to_go_back_to
    return if check_permission(@sequence)

    flash_warning(:permission_denied.t)
    redirect_with_query(@sequence.observation.show_link_args)
  end

  def update
    @sequence = find_or_goto_index(Sequence, params[:id].to_s)
    return unless @sequence

    figure_out_where_to_go_back_to
    if check_permission(@sequence)
      save_edits
    else
      flash_warning(:permission_denied.t)
      redirect_with_query(@sequence.observation.show_link_args)
    end
  end

  def destroy
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
      redirect_with_query(action: :index)
    else
      redirect_with_query(@back_object.show_link_args)
    end
  end

  ##############################################################################

  private

  def figure_out_where_to_go_back_to
    @back = params[:back]
    @back_object = @back == "show" ? @sequence : @sequence.observation
  end

  # ---------- Index -----------------------------------------------------------

  def index_all
    store_location
    query = create_query(:Sequence, :all)
    show_selected_sequences(query)
  end

  def index_observation
    store_location
    query = create_query(:Sequence, :for_observation,
                         observation: params[:id].to_s)
    @links = [
      [:show_object.l(type: :observation),
       Observation.show_link_args(params[:id])],
      [:show_observation_add_sequence.l,
       { action: :create, id: params[:id] }]
    ]
    show_selected_sequences(query, always_index: true)
  end

  def patterned_index
    pattern = params[:pattern].to_s
    if pattern.match?(/^\d+$/) && (sequence = Sequence.safe_find(pattern))
      redirect_to(sequence_path(sequence.id))
    else
      show_selected_sequences(
        create_query(:Sequence, :pattern_search, pattern: pattern)
      )
    end
  end

  def show_selected_sequences(query, args = {})
    args = { include: [{ observation: :name }, :user],
             letters: "sequences.locus",
             num_per_page: 50 }.merge(args)
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

  # ---------- Create, Edit ----------------------------------------------------

  def build_sequence
    @sequence = @observation.sequences.new
    @sequence.attributes = sequence_params
    @sequence.user = @user
    if @sequence.save
      flash_notice(:runtime_sequence_success.t(id: @sequence.id))
      redirect_with_query(@observation.show_link_args)
    else
      flash_object_errors(@sequence)
    end
  end

  def save_edits
    @sequence.attributes = sequence_params
    if @sequence.save
      flash_notice(:runtime_sequence_success.t(id: @sequence.id))
      redirect_with_query(@back_object.show_link_args)
    else
      flash_object_errors(@sequence)
    end
  end

  # ---------- Strong Parameters -----------------------------------------------

  def sequence_params
    params[:sequence].permit(:archive, :accession, :bases, :locus, :notes)
  end
end
