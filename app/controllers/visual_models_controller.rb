# frozen_string_literal: true

class VisualModelsController < ApplicationController
  before_action :login_required

  # GET /visual_models or /visual_models.json
  def index
    @visual_models = VisualModel.all.order(:name)
  end

  # GET /visual_models/1 or /visual_models/1.json
  def show
    @visual_model = VisualModel.find(params[:id])
  end

  # GET /visual_models/new
  def new
    @visual_model = VisualModel.new
  end

  #   # GET /visual_models/1/edit
  #   def edit
  #   end

  # POST /visual_models or /visual_models.json
  def create
    @visual_model = VisualModel.new(visual_model_params)

    respond_to do |format|
      if @visual_model.save
        format.html do
          redirect_to(visual_model_url(@visual_model),
                      notice: runtime_visual_model_created_at.t)
        end
        format.json do
          render(:show, status: :created,
                        location: @visual_model)
        end
      else
        format.html { render(:new, status: :unprocessable_entity) }
        format.json do
          render(json: @visual_model.errors,
                 status: :unprocessable_entity)
        end
      end
    end
  end

  #   # PATCH/PUT /visual_models/1 or /visual_models/1.json
  #   def update
  #     respond_to do |format|
  #       if @visual_model.update(visual_model_params)
  #         format.html { redirect_to visual_model_url(@visual_model),
  # notice: "Visual model was successfully updated." }
  #         format.json { render :show, status: :ok, location: @visual_model }
  #       else
  #         format.html { render :edit, status: :unprocessable_entity }
  #         format.json { render json: @visual_model.errors,
  # status: :unprocessable_entity }
  #       end
  #     end
  #   end

  # DELETE /visual_models/1 or /visual_models/1.json
  def destroy
    @visual_model = VisualModel.find(params[:id])
    @visual_model.destroy

    respond_to do |format|
      format.html do
        redirect_to(visual_models_url,
                    notice: :destroy_visual_model_success.t)
      end
      format.json { head(:no_content) }
    end
  end

  #   private
  #     # Use callbacks to share common setup or constraints between actions.
  #     def set_visual_model
  #       @visual_model = VisualModel.find(params[:id])
  #     end

  #     # Only allow a list of trusted parameters through.
  #     def visual_model_params
  #       params.require(:visual_model).permit(:name, :reviewed)
  #     end
end
