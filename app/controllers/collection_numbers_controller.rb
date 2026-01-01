# frozen_string_literal: true

# Controls viewing and modifying collection numbers.
# rubocop:disable Metrics/ClassLength
class CollectionNumbersController < ApplicationController
  before_action :login_required
  before_action :store_location, except: [:destroy]

  ##############################################################################
  # INDEX
  #
  def index
    build_index_with_query
  end

  private

  def default_sort_order
    nil # Query::CollectionNumbers.default_order
  end

  def index_active_params
    [:pattern, :observation, :by, :q, :id].freeze
  end

  # Display list of CollectionNumbers for an Observation
  def observation
    @observation = Observation.find(params[:observation])
    query = create_query(
      :CollectionNumber, observations: params[:observation].to_s
    )
    [query, { always_index: true }]
  end

  def index_display_opts(opts, _query)
    {
      letters: true,
      num_per_page: 100
    }.merge(opts)
  end

  public

  ##############################################################################

  def show
    case params[:flow]
    when "next"
      redirect_to_next_object(:next, CollectionNumber, params[:id]) and return
    when "prev"
      redirect_to_next_object(:prev, CollectionNumber, params[:id]) and return
    end

    @canonical_url = CollectionNumber.show_url(params[:id])
    @collection_number = find_or_goto_index(CollectionNumber, params[:id])
  end

  def new
    set_ivars_for_new
    return unless @observation
    return unless make_sure_can_edit!(@observation)

    @collection_number = CollectionNumber.new(name: @user.legal_name)

    respond_to do |format|
      format.turbo_stream { render_modal_collection_number_form }
      format.html
    end
  end

  def create
    set_ivars_for_new
    return unless @observation
    return unless make_sure_can_edit!(@observation)

    create_collection_number # response handled here
  end

  def edit
    set_ivars_for_edit
    return unless @collection_number

    figure_out_where_to_go_back_to
    return unless make_sure_can_edit!(@collection_number)

    respond_to do |format|
      format.turbo_stream { render_modal_collection_number_form }
      format.html
    end
  end

  def update
    set_ivars_for_edit
    return unless @collection_number

    figure_out_where_to_go_back_to
    return unless make_sure_can_edit!(@collection_number)

    update_collection_number # response handled here
  end

  def destroy
    @collection_number = find_or_goto_index(CollectionNumber, params[:id])
    return unless @collection_number
    return unless make_sure_can_delete!(@collection_number)

    figure_out_where_to_go_back_to
    @observation = @back_object if @back_object.is_a?(Observation)
    @collection_number.destroy

    respond_to do |format|
      # Only render turbo_stream if we have an observation to update
      format.turbo_stream do
        if @observation
          render_collection_numbers_section_update
        else
          redirect_with_query(action: :index)
        end
      end
      format.html { redirect_with_query(action: :index) }
    end
  end

  private

  def set_ivars_for_new
    @layout = calc_layout_params
    @observation = find_or_goto_index(Observation, params[:observation_id])
    @back_object = @observation
  end

  def set_ivars_for_edit
    @layout = calc_layout_params
    @collection_number = find_or_goto_index(CollectionNumber, params[:id])
  end

  # create
  def create_collection_number
    @collection_number =
      CollectionNumber.new(permitted_collection_number_params)
    normalize_parameters
    return if form_has_errors?

    if name_and_number_free?
      save_collection_number_and_update_associations
    else
      flash_collection_number_already_used_and_return
    end
  end

  # create, update
  def form_has_errors?
    unless validate_collection_number?
      flash_and_reload_form
      return true
    end
    false
  end

  def validate_collection_number?
    if @collection_number.name.blank?
      flash_error(:create_collection_number_missing_name.t)
      return false
    elsif @collection_number.number.blank?
      flash_error(:create_collection_number_missing_number.t)
      return false
    end
    true
  end

  def flash_and_reload_form
    redirect_params = case action_name # this is a rails var
                      when "create"
                        { action: :new }
                      when "update"
                        { action: :edit }
                      end
    redirect_params[:back] = @back if @back.present?

    respond_to do |format|
      format.html do
        redirect_to(redirect_params)
      end
      format.turbo_stream do
        reload_collection_number_modal_form_and_flash
      end
    end
  end

  # create
  def save_collection_number_and_update_associations
    @collection_number.save
    @collection_number.add_observation(@observation)
    flash_notice(
      :runtime_added_to.t(type: :collection_number, name: :observation)
    )
    respond_to do |format|
      format.html do
        redirect_to_back_object_or_object(@back_object, @collection_number)
      end
      format.turbo_stream do
        render_collection_numbers_section_update
      end
    end
  end

  # create
  def flash_collection_number_already_used_and_return
    flash_warning(:edit_collection_number_already_used.t) if
      @other_number.observations.any?
    @other_number.add_observation(@observation)
    @collection_number = @other_number
    show_flash_and_send_back
  end

  # update
  def update_collection_number
    old_format_name = @collection_number.format_name
    @collection_number.attributes = permitted_collection_number_params
    normalize_parameters
    return if form_has_errors?

    if name_and_number_free?
      update_collection_number_and_associations(old_format_name)
    else
      flash_numbers_merged_and_update_associations(old_format_name)
    end
  end

  # update
  def update_collection_number_and_associations(old_format_name)
    @collection_number.save
    @collection_number.change_corresponding_herbarium_records(old_format_name)
    flash_notice(:runtime_updated_at.t(type: :collection_number))

    respond_to do |format|
      format.html do
        redirect_to_back_object_or_object(@back_object, @collection_number)
      end
      format.turbo_stream do
        # if we're here, we're on an obs page.
        # back_object should be the obs, sent via :back param from the link
        @observation = @back_object
        render_collection_numbers_section_update
      end
    end
  end

  # update
  def flash_numbers_merged_and_update_associations(old_format_name)
    flash_warning(
      :edit_collection_numbers_merged.t(
        this: old_format_name,
        that: @other_number.format_name
      )
    )
    @collection_number.change_corresponding_herbarium_records(old_format_name)
    @other_number.observations += @collection_number.observations -
                                  @other_number.observations
    @collection_number.destroy
    @collection_number = @other_number

    show_flash_and_send_back
  end

  def permitted_collection_number_params
    return {} unless params[:collection_number]

    params.require(:collection_number).permit(:name, :number)
  end

  def make_sure_can_edit!(obj)
    return true if in_admin_mode? || obj.can_edit?

    flash_error(:permission_denied.t)
    show_flash_and_send_back
    false
  end

  def make_sure_can_delete!(collection_number)
    return true if collection_number.can_edit? || in_admin_mode?

    flash_error(:permission_denied.t)
    redirect_to(collection_number_path(collection_number.id))
    false
  end

  def normalize_parameters
    [:name, :number].each do |arg|
      val = @collection_number.send(arg).to_s.strip_html.strip_squeeze
      @collection_number.send(:"#{arg}=", val)
    end
  end

  def name_and_number_free?
    @other_number = CollectionNumber.where(
      name: @collection_number.name,
      number: @collection_number.number
    ).first
    !@other_number || @other_number == @collection_number
  end

  def figure_out_where_to_go_back_to
    @back = params[:back]
    @back_object = nil
    if @back == "show"
      @back_object = @collection_number
    elsif @back != "index"
      @back_object = Observation.safe_find(@back)
      return if @back_object

      @back_object = if @collection_number.observations.one?
                       @collection_number.observations.first
                     else
                       @collection_number
                     end
    end
  end

  def show_flash_and_send_back
    respond_to do |format|
      format.html do
        redirect_to_back_object_or_object(@back_object, @collection_number) and
          return
      end
      # renders the flash in the modal
      format.turbo_stream do
        render(partial: "shared/modal_flash_update",
               locals: { identifier: modal_identifier }) and return
      end
    end
  end

  def render_modal_collection_number_form
    render(Components::ModalForm.new(
             identifier: modal_identifier,
             title: modal_title,
             user: @user,
             model: @collection_number,
             observation: @observation,
             back: @back
           ))
  end

  def modal_identifier
    case action_name
    when "new", "create"
      "collection_number"
    when "edit", "update"
      "collection_number_#{@collection_number.id}"
    end
  end

  def modal_title
    case action_name
    when "new", "create"
      helpers.new_page_title(:add_object, :COLLECTION_NUMBER)
    when "edit", "update"
      helpers.edit_page_title(
        @collection_number.format_name.t, @collection_number
      )
    end
  end

  # ivar @observation used in the partial
  def render_collection_numbers_section_update
    render(
      partial: "observations/show/section_update",
      locals: { identifier: "collection_numbers",
                obs: @observation, user: @user }
    ) and return
  end

  # this updates both the form and the flash
  def reload_collection_number_modal_form_and_flash
    render(
      partial: "shared/modal_form_reload",
      locals: {
        identifier: modal_identifier,
        form: "collection_numbers/form",
        form_locals: {
          model: @collection_number,
          observation: @observation,
          back: @back
        }
      }
    ) and return true
  end
end
# rubocop:enable Metrics/ClassLength
