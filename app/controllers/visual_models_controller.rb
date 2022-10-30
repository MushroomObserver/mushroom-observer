# frozen_string_literal: true

class VisualModelsController < ApplicationController
  before_action :login_required

  # GET /visual_models
  def index
    @visual_models = VisualModel.all.order(:name)
  end

  # GET /visual_models/1
  def show
    @visual_model = VisualModel.find(params[:id])
  end

  # GET /visual_models/new
  def new
    @visual_model = VisualModel.new
  end

  # GET /visual_models/1/edit
  def edit
    @visual_model = VisualModel.find(params[:id])
  end

  # POST /visual_models
  def create
    @visual_model = VisualModel.new(visual_model_params)
    if @visual_model.save
      redirect_to(visual_model_url(@visual_model),
                  notice: :runtime_visual_model_created_at.t)
    end
  end

  # PATCH/PUT /visual_models/1
  def update
    @visual_model = VisualModel.find(params[:id])

    if @visual_model.update(visual_model_params)
      redirect_to(visual_model_url(@visual_model),
                  notice: :runtime_visual_model_updated_at.t)
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

  # Use callbacks to share common setup or constraints between actions.
  def set_visual_model
    @visual_model = VisualModel.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def visual_model_params
    params.require(:visual_model).permit(:name, :reviewed)
  end
end
