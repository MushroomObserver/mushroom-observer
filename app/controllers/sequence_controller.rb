#  Controller for nucleotide Sequences
#
#  Actions
#
#    add_sequence::      Create new sequence and add to Observation
#    destroy_sequence::  Destroy sequence
#    edit_sequence::     Update sequence
#    index_sequence::    List selected sequences, based on current Query
#    show_sequence::     Display sequence details
#
#
class SequenceController < ApplicationController
  before_action :login_required, except: [
    :show_sequence,
    :index_sequence
  ]

  def index_sequence
    pass_query_params
    store_location
    query = find_or_create_query(:Sequence, by: params[:by])
    show_selected_sequences(query, id: params[:id].to_s, always_index: true)
  end

  def show_sequence
    pass_query_params
    store_location
    @sequence = find_or_goto_index(Sequence, params[:id].to_s)
  end

  def add_sequence
    pass_query_params
    @observation = find_or_goto_index(Observation, params[:id].to_s)
    return unless @observation
    if !check_permission(@observation)
      flash_warning(:permission_denied.t)
      redirect_with_query(@observation.show_link_args)
    elsif request.method == "POST"
      build_sequence
    end
  end

  def edit_sequence
    pass_query_params
    @sequence = find_or_goto_index(Sequence, params[:id].to_s)
    return unless @sequence
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
    observation = @sequence.observation
    if check_permission(@sequence)
      @sequence.destroy
      flash_notice(:runtime_destroyed_id.t(type: Sequence, value: params[:id]))
    else
      flash_warning(:permission_denied.t)
    end
    redirect_with_query(observation.show_link_args)
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
      redirect_with_query(@sequence.observation.show_link_args)
    else
      flash_object_errors(@sequence)
    end
  end

  def show_selected_sequences(query, args = {})
    args = { action: :list_sequences,
             letters: "sequences.locus",
             num_per_page: 50 }.merge(args)
    @links ||= []
    args[:sorting_links] = show_sequence_sorts
    show_index_of_objects(query, args)
  end

  def show_sequence_sorts
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
