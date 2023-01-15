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
    @filter = params[:filter]
    @visual_group = VisualGroup.find(params[:id])
    @vals = calc_show_vals(calc_layout_params["count"])
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
    @filter = params[:filter]
    @filter = @visual_group.name unless @filter && @filter != ""
    @status = status_from_params(params)
    @vals = calc_edit_vals(calc_layout_params["count"])
  end

  def status_from_params(params)
    return "included" if params[:commit] == :visual_group_included.t
    return "excluded" if params[:commit] == :visual_group_excluded.t

    params[:status] || "needs_review"
  end

  # POST /visual_groups or /visual_groups.json
  def create
    params = visual_group_params
    if params.include?(:name_list)
      create_from_list(params)
    else
      create_one_visual_group(params)
    end
  end

  def create_from_list(params)
    model = VisualModel.find(params[:visual_model_id])
    params[:name_list].split(/[\n,\r]/).each do |raw_name|
      name = raw_name.strip
      create_visual_group(model, name) if name != ""
    end
    redirect_to(visual_model_visual_groups_url(model))
  end

  def create_visual_group(model, name)
    group = VisualGroup.new(visual_model: model, name: name)
    if group.save
      group.add_initial_images
    else
      flash_object_errors(group)
    end
  end

  def create_one_visual_group(params)
    @visual_group = VisualGroup.new(params)
    @visual_group.visual_model = VisualModel.find(params[:visual_model_id])

    if @visual_group.save
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
    params.permit(:visual_group, :name_list,
                  :visual_model_id, :name,
                  :approved, :description)
  end

  def calc_show_vals(count)
    if !@filter || @filter == ""
      @visual_group.visual_group_images.where(included: true).
        pluck(:image_id, :included)
    else
      vgi = VisualGroupImages.new(@filter, true, count)
      vgi.vals
    end
  end

  def calc_edit_vals(count)
    if @status != "needs_review"
      return @visual_group.visual_group_images.
             where(included: @status != "excluded").pluck(:image_id, :included)
    end
    VisualGroupImages.new(@filter, nil, count).vals
  end
end
