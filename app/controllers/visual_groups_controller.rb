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

    if @visual_group.save
      redirect_to(visual_model_visual_groups_url(@visual_group.visual_model, @visual_group),
                  notice: :runtime_visual_group_created_at.t)
    else
      render(:new, status: :unprocessable_entity)
    end
  end

  #   # PATCH/PUT /visual_groups/1 or /visual_groups/1.json
  #   def update
  #     respond_to do |format|
  #       if @visual_group.update(visual_group_params)
  #         format.html { redirect_to visual_group_url(@visual_group),
  # notice: "Visual group was successfully updated." }
  #         format.json { render :show, status: :ok, location: @visual_group }
  #       else
  #         format.html { render :edit, status: :unprocessable_entity }
  #         format.json { render json: @visual_group.errors,
  # status: :unprocessable_entity }
  #       end
  #     end
  #   end

  # DELETE /visual_groups/1 or /visual_groups/1.json
  def destroy
    @visual_group = VisualGroup.find(params[:id])
    @visual_group.destroy

    respond_to do |format|
      format.html do
        redirect_to(visual_groups_url,
                    notice: :destroy_visual_group_success.t)
      end
      format.json { head(:no_content) }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_visual_group
    @visual_group = VisualGroup.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def visual_group_params
    params.require(:visual_group).permit(:visual_model_id, :name,
                                         :approved, :description)
  end
end
