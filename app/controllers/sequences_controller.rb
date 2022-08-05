# frozen_string_literal: true

#  Controller for nucleotide Sequences
#
#  Actions:
#
#    create::           Create new sequence and add to Observation
#    destroy::          Destroy sequence
#    edit::             Show form to edit a sequence
#    index::            List selected sequences, based on current Query
#    list::             ???
#    next::             show next sequence
#    observation_index  ???
#    prev::             show previous sequence
#    search::           ???
#    show::             Display sequence details.
#
class SequencesController < ApplicationController
  before_action :login_required
  # except: [
  #   :index,
  #   :list,
  #   :search,
  #   :index,
  #   :show,
  #   :next,
  #   :prev
  # ]

  ################# Actions that show data without modifying it

  def index
    return patterned_index if params[:pattern].present?

    case params[:flavor]
    when "all"
      store_location
      query = create_query(:Sequence, :all)
      show_selected_sequences(query)
    else
      query = find_or_create_query(:Sequence, by: params[:by])
      show_selected_sequences(query, id: params[:id].to_s, always_index: true)
    end
  end

=begin
  def observation_index
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
=end

  def show
    pass_query_params
    store_location

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
    store_location
    pass_query_params
    @observation = find_or_goto_index(Observation, params[:id].to_s)
    return unless @observation
  end

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
    if !check_permission(@sequence)
      flash_warning(:permission_denied.t)
      redirect_with_query(@sequence.observation.show_link_args)
    end
  end

  def update
    store_location
    pass_query_params
    @sequence = find_or_goto_index(Sequence, params[:id].to_s)
    return unless @sequence

    figure_out_where_to_go_back_to
    if !check_permission(@sequence)
      flash_warning(:permission_denied.t)
      redirect_with_query(@sequence.observation.show_link_args)
    else
      save_edits
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
    args = { action: :list,
             include: [{ observation: :name }, :user],
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

  # ---------- Strong Psrameters -----------------------------------------------

  def sequence_params
    params[:sequence].permit(:archive, :accession, :bases, :locus, :notes)
  end
end
