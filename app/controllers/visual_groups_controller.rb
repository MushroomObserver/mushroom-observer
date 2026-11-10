# frozen_string_literal: true

class VisualGroupsController < ApplicationController
  before_action :login_required

  # GET /visual_groups or /visual_groups.json
  def index
    @visual_model = VisualModel.find(params[:visual_model_id])
    @visual_groups = @visual_model.visual_groups.order(:name).to_a
    render(Views::Controllers::VisualGroups::Index.new(
             visual_model: @visual_model,
             visual_groups: @visual_groups
           ))
  end

  # GET /visual_groups/1 or /visual_groups/1.json
  def show
    @filter = params.permit(:filter)[:filter]
    @visual_group = VisualGroup.find(params[:id])
    query_params = { visual_groups: [@visual_group],
                     visual_group_included: true }
    query_params[:this_name] = @filter if @filter.present?
    paginate_group_images(query_params, true)
    render(Views::Controllers::VisualGroups::Show.new(
             visual_group: @visual_group, user: @user, filter: @filter,
             pagination_data: @pagination_data, subset: @subset
           ))
  end

  # GET /visual_groups/new
  def new
    @visual_model = VisualModel.find(params[:visual_model_id])
    @visual_group = VisualGroup.new
    render(Views::Controllers::VisualGroups::New.new(
             visual_model: @visual_model, visual_group: @visual_group
           ))
  end

  # GET /visual_groups/1/edit
  def edit
    @visual_group = VisualGroup.find(params[:id])
    @filter = edit_filter.filter
    @filter = @visual_group.name unless @filter && @filter != ""
    @status = edit_filter.status
    if @status == "needs_review"
      paginate_group_images({ visual_group_unreviewed: [@visual_group],
                              this_name: @filter }, nil)
    else
      included = @status != "excluded"
      paginate_group_images({ visual_groups: [@visual_group],
                              visual_group_included: included }, included)
    end
    render(Views::Controllers::VisualGroups::Edit.new(
             visual_group: @visual_group, user: @user,
             filter: @filter, status: @status,
             pagination_data: @pagination_data, subset: @subset
           ))
  end

  # Top-nav rubric support (Views::Layouts::TopNav#extra_nav_index_params):
  # the index route is nested under visual_model_id, which show/edit
  # don't carry in params (shallow routing flattens member actions) --
  # derive it from the loaded record instead.
  def nav_index_params
    model = @visual_group&.visual_model || @visual_model
    return {} unless model

    { visual_model_id: model.id }
  end

  # Paginates at the DB level via Query instead of loading every
  # matching visual_group_image + its Image into memory and slicing
  # the array -- a group with thousands of images would otherwise
  # do that full load on every page request. `included` is the
  # fixed included/excluded/nil (needs_review) value every row in
  # this query_params shares -- not a per-row value from the join,
  # since each branch's query already filters down to one value.
  def paginate_group_images(query_params, included)
    @pagination_data = PaginationData.new(
      number_arg: :page,
      number: params[:page],
      num_per_page: calc_layout_params["count"]
    )
    query = create_query(:Image, **query_params)
    images = query.paginate(@pagination_data)
    @subset = images.map { |image| [image, included] }
  end

  def edit_filter
    @edit_filter ||= FormObject::VisualGroupFilter.new(edit_filter_params)
  end

  # `?visual_group_filter=foo` (a String, not a nested hash) would
  # otherwise reach `.permit` and raise NoMethodError -- guard the
  # type before calling it.
  def edit_filter_params
    raw = params[:visual_group_filter]
    return {} unless raw.is_a?(ActionController::Parameters)

    raw.permit(:status, :filter)
  end

  # POST /visual_groups or /visual_groups.json
  def create
    if save_visual_group
      @visual_group.add_initial_images
      redirect_to(visual_model_visual_groups_url(@visual_group.visual_model,
                                                 @visual_group),
                  notice: :runtime_visual_group_created_at.t)
    else
      flash_object_errors(@visual_group)
      redirect_to(new_visual_model_visual_group_url(@visual_group.visual_model))
    end
  end

  # PATCH/PUT /visual_groups/1 or /visual_groups/1.json
  def update
    @visual_group = VisualGroup.find(params[:id])
    if @visual_group.update(visual_group_params)
      redirect_to(visual_model_visual_groups_url(@visual_group.visual_model,
                                                 @visual_group),
                  notice: :update_visual_group_success.t(
                    name: @visual_group.name
                  ))
    else
      flash_object_errors(@visual_group)
      redirect_to(edit_visual_group_url(@visual_group))
    end
  end

  # DELETE /visual_groups/1 or /visual_groups/1.json
  def destroy
    @visual_group = VisualGroup.find(params[:id])
    model = @visual_group.visual_model
    @visual_group.destroy

    redirect_to(visual_model_visual_groups_url(model),
                notice: :destroy_visual_group_success.t)
  end

  private

  # Only allow a list of trusted parameters through.
  def visual_group_params
    params.require(:visual_group).permit(:name, :approved, :description)
  end

  def save_visual_group
    @visual_group = VisualGroup.new(visual_group_params)
    @visual_group.visual_model = VisualModel.find(params[:visual_model_id])
    @visual_group.save
  end
end
