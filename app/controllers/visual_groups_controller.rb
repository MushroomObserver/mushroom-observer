# frozen_string_literal: true

class VisualGroupsController < ApplicationController
  before_action :login_required

  # GET /visual_groups or /visual_groups.json
  def index
    @visual_model = VisualModel.find(params[:visual_model_id])
    @visual_groups = @visual_model.visual_groups.order(:name)
  end

  # GET /visual_groups/1 or /visual_groups/1.json
  def show
    logger.debug(VisualGroupData.new("Agaricus sylvicola", 1.5).sql_query)
    @visual_group = VisualGroup.find(params[:id])
  end

  # GET /visual_groups/new
  def new
    @visual_model = VisualModel.find(params[:visual_model_id])
    @visual_group = VisualGroup.new
  end

  # GET /visual_groups/1/edit
  def edit
    pass_query_params
    @visual_group = VisualGroup.find(params[:id])
    query = create_query(:Image, :pattern_search, by: :created_at,
                                                  pattern: @visual_group.name)
    @layout = calc_layout_params
    @pages = paginate_numbers(:page, @layout["count"])
    @objects = query.paginate(@pages,
                              include: [:user, { observations: :name }])
  end

  # POST /visual_groups or /visual_groups.json
  def create
    @visual_group = VisualGroup.new(visual_group_params)
    @visual_group.visual_model = VisualModel.find(params[:visual_model_id])

    @visual_group.save!
    redirect_to(visual_model_visual_groups_url(@visual_group.visual_model,
                                               @visual_group),
                notice: :runtime_visual_group_created_at.t)
  end

  # PATCH/PUT /visual_groups/1 or /visual_groups/1.json
  def update
    @visual_group = VisualGroup.find(params[:id])
    @visual_group.update!(visual_group_params)
    redirect_to(visual_model_visual_groups_url(@visual_group.visual_model,
                                               @visual_group),
                notice: :update_visual_group_success.t)
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
    params.require(:visual_group).permit(:visual_model_id, :name,
                                         :approved, :description)
  end
end
