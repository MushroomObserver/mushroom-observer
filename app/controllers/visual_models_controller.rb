# frozen_string_literal: true

class VisualModelsController < ApplicationController
  before_action :login_required

  # GET /visual_models
  def index
    @visual_models = VisualModel.order(:name).to_a
    render(Views::Controllers::VisualModels::Index.new(
             visual_models: @visual_models
           ))
  end

  # GET /visual_models/1
  def show
    @visual_model = VisualModel.find(params[:id])
    @visual_groups = @visual_model.visual_groups.order(:name).to_a
    respond_to do |format|
      format.html do
        render(Views::Controllers::VisualModels::Show.new(
                 visual_model: @visual_model,
                 visual_groups: @visual_groups
               ))
      end
      format.json { render(json: @visual_model) }
    end
  end

  # GET /visual_models/new
  def new
    @visual_model = VisualModel.new
    render(Views::Controllers::VisualModels::New.new(
             visual_model: @visual_model
           ))
  end

  # GET /visual_models/1/edit
  def edit
    @visual_model = VisualModel.find(params[:id])
    render(Views::Controllers::VisualModels::Edit.new(
             visual_model: @visual_model
           ))
  end

  # POST /visual_models
  def create
    @visual_model = VisualModel.new(visual_model_params)
    if @visual_model.save
      redirect_to(visual_model_url(@visual_model),
                  notice: :runtime_visual_model_created_at.t)
    else
      flash_object_errors(@visual_model)
      redirect_to(new_visual_model_url)
    end
  end

  # PATCH/PUT /visual_models/1
  def update
    @visual_model = VisualModel.find(params[:id])

    if @visual_model.update(visual_model_params)
      redirect_to(visual_model_url(@visual_model),
                  notice: :runtime_visual_model_updated_at.t)
    else
      flash_object_errors(@visual_model)
      redirect_to(edit_visual_model_url(@visual_model))
    end
  end

  # DELETE /visual_models/1
  def destroy
    @visual_model = VisualModel.find(params[:id])
    @visual_model.destroy

    redirect_to(visual_models_url,
                notice: :destroy_visual_model_success.t)
  end

  private

  # Only allow a list of trusted parameters through.
  def visual_model_params
    params.require(:visual_model).permit(:name, :reviewed)
  end
end
