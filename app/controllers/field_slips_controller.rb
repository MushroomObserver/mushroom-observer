class FieldSlipsController < ApplicationController
  before_action :set_field_slip, only: %i[ show edit update destroy ]

  # GET /field_slips or /field_slips.json
  def index
    @field_slips = FieldSlip.all
  end

  # GET /field_slips/1 or /field_slips/1.json
  def show
  end

  # GET /field_slips/new
  def new
    @field_slip = FieldSlip.new
  end

  # GET /field_slips/1/edit
  def edit
  end

  # POST /field_slips or /field_slips.json
  def create
    @field_slip = FieldSlip.new(field_slip_params)

    respond_to do |format|
      if @field_slip.save
        format.html { redirect_to field_slip_url(@field_slip), notice: "Field slip was successfully created." }
        format.json { render :show, status: :created, location: @field_slip }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @field_slip.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /field_slips/1 or /field_slips/1.json
  def update
    respond_to do |format|
      if @field_slip.update(field_slip_params)
        format.html { redirect_to field_slip_url(@field_slip), notice: "Field slip was successfully updated." }
        format.json { render :show, status: :ok, location: @field_slip }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @field_slip.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /field_slips/1 or /field_slips/1.json
  def destroy
    @field_slip.destroy!

    respond_to do |format|
      format.html { redirect_to field_slips_url, notice: "Field slip was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_field_slip
      @field_slip = FieldSlip.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def field_slip_params
      params.require(:field_slip).permit(:observation_id, :project_id, :identifier)
    end
end
