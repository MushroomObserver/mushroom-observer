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
class SequenceController < ApplicationController
  before_action :login_required, except: [
    :index_sequence,
    :list_sequences,
    :sequence_search,
    :observation_index,
    :show_sequence,
    :next_sequence,
    :prev_sequence
  ]

  def index_sequence # :norobots:
    query = find_or_create_query(:Sequence, by: params[:by])
    show_selected_sequences(query, id: params[:id].to_s, always_index: true)
  end

  def list_sequences # :norobots:
    store_location
    query = create_query(:Sequence, :all)
    show_selected_sequences(query)
  end

  # Display list of Sequences whose text matches a string pattern.
  def sequence_search # :norobots:
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) &&
       (sequence = Sequence.safe_find(pattern))
      redirect_to(action: :show_sequence, id: sequence.id)
    else
      query = create_query(:Sequence, :pattern_search, pattern: pattern)
      show_selected_sequences(query)
    end
  end

  def observation_index # :norobots:
    store_location
    query = create_query(:Sequence, :for_observation,
                         observation: params[:id].to_s)
    @links = [
      [:show_object.l(type: :observation),
       Observation.show_link_args(params[:id])],
      [:show_observation_add_sequence.l,
       { action: :create_sequence, id: params[:id] }]
    ]
    show_selected_sequences(query, always_index: true)
  end

  def show_sequence
    pass_query_params
    store_location
    @sequence = find_or_goto_index(Sequence, params[:id].to_s)
  end

  def next_sequence # :norobots:
    redirect_to_next_object(:next, Sequence, params[:id].to_s)
  end

  def prev_sequence # :norobots:
    redirect_to_next_object(:prev, Sequence, params[:id].to_s)
  end

  def create_sequence
    store_location
    pass_query_params
    @observation = find_or_goto_index(Observation, params[:id].to_s)
    return unless @observation

    build_sequence if request.method == "POST"
  end

  def edit_sequence
    store_location
    pass_query_params
    @sequence = find_or_goto_index(Sequence, params[:id].to_s)
    return unless @sequence

    figure_out_where_to_go_back_to
    if !check_permission(@sequence)
      flash_warning(:permission_denied.t)
      redirect_with_query(@sequence.observation.show_link_args)
    elsif request.method == "POST"
      save_edits
    end
  end

  def destroy_sequence
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
      redirect_with_query(action: :index_sequence)
    else
      redirect_with_query(@back_object.show_link_args)
    end
  end

  ##############################################################################

  private

  def build_sequence
    @sequence = @observation.sequences.new
    @sequence.attributes = whitelisted_sequence_params
    @sequence.user = @user
    if @sequence.save
      flash_notice(:runtime_sequence_success.t(id: @sequence.id))
      redirect_with_query(@observation.show_link_args)
    else
      flash_object_errors(@sequence)
    end
  end

  def save_edits
    @sequence.attributes = whitelisted_sequence_params
    if @sequence.save
      flash_notice(:runtime_sequence_success.t(id: @sequence.id))
      redirect_with_query(@back_object.show_link_args)
    else
      flash_object_errors(@sequence)
    end
  end

  def figure_out_where_to_go_back_to
    @back = params[:back]
    @back_object = @back == "show" ? @sequence : @sequence.observation
  end

  def show_selected_sequences(query, args = {})
    args = { action: :list_sequences,
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

  def whitelisted_sequence_params
    params[:sequence].permit(:archive, :accession, :bases, :locus, :notes)
  end
end
