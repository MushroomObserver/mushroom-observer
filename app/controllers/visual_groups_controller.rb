# frozen_string_literal: true

class VisualGroupsController < ApplicationController
  before_action :login_required

  # GET /visual_groups or /visual_groups.json
  def index
    @visual_groups = VisualGroup.joins(
      "LEFT JOIN names ON visual_groups.group_name_id = names.id"
    ).order(
      "names.text_name"
    )
  end

  #   # GET /visual_groups/1 or /visual_groups/1.json
  #   def show
  #   end

  #   # GET /visual_groups/new
  #   def new
  #     @visual_group = VisualGroup.new
  #   end

  #   # GET /visual_groups/1/edit
  #   def edit
  #   end

  #   # POST /visual_groups or /visual_groups.json
  #   def create
  #     @visual_group = VisualGroup.new(visual_group_params)

  #     respond_to do |format|
  #       if @visual_group.save
  #         format.html { redirect_to visual_group_url(@visual_group),
  #            notice: "Visual group was successfully created." }
  #         format.json { render :show, status: :created,
  # location: @visual_group }
  #       else
  #         format.html { render :new, status: :unprocessable_entity }
  #         format.json { render json: @visual_group.errors,
  # status: :unprocessable_entity }
  #       end
  #     end
  #   end

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

  #   # DELETE /visual_groups/1 or /visual_groups/1.json
  #   def destroy
  #     @visual_group.destroy

  #     respond_to do |format|
  #       format.html { redirect_to visual_groups_url,
  # notice: "Visual group was successfully destroyed." }
  #       format.json { head :no_content }
  #     end
  #   end

  #   private
  #     # Use callbacks to share common setup or constraints between actions.
  #     def set_visual_group
  #       @visual_group = VisualGroup.find(params[:id])
  #     end

  #     # Only allow a list of trusted parameters through.
  #     def visual_group_params
  #       params.require(:visual_group).permit(:name_id, :reviewed)
  #     end
end
