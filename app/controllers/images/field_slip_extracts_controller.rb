# frozen_string_literal: true

module Images
  # Machine-reads a field slip photo and lets a site admin review the
  # result before any of it reaches the observation (see
  # FieldSlip::Extractor).
  #
  # Admin-only for now, and not because of permissions: every call costs
  # money and roughly a third of fields need correcting, so this wants a
  # small number of people who know what a slip should say. `create`
  # always re-reads -- extraction changes over time and a fresh read is
  # the point of pressing the button again.
  class FieldSlipExtractsController < ApplicationController
    before_action :login_required
    before_action :admin_required
    before_action :find_image!

    def create
      result = FieldSlip::Extractor.default.extract(@image, context: context)
      FieldSlipExtract.record(
        image: @image, user: @user, result: result,
        prompt_version: FieldSlip::Extractor::PROMPT_VERSION
      )
      redirect_to(edit_image_field_slip_extract_path(@image.id))
    rescue StandardError => e
      flash_error(:field_slip_extract_failed.t(error: e.message))
      redirect_to(image_path(@image.id))
    end

    def edit
      return unless extract_or_redirect!

      # No `layout:` option -- `Views::FullPageBase#around_template`
      # picks the wrapping layout itself (see ApplicationController).
      render(Views::Controllers::Images::FieldSlipExtracts::Edit.new(
               extract: @extract, observation: @observation, user: @user
             ))
    end

    def update
      return unless extract_or_redirect!

      apply_chosen_fields
      flash_notice(:field_slip_extract_saved.t)
      redirect_to(permanent_observation_path(@observation.id))
    end

    private

    # No return value: a `before_action` halts the chain when it
    # redirects, so signalling with true/false would be decoration.
    def admin_required
      return if in_admin_mode?

      flash_error(:permission_denied.t)
      redirect_to(image_path(params[:image_id]))
    end

    def find_image!
      @image = Image.safe_find(params[:image_id])
      return @image if @image

      flash_error(:runtime_image_not_found.t(id: params[:image_id]))
      redirect_to(images_path)
      nil
    end

    def context
      FieldSlip::Extractor::Context.for_image(@image)
    end

    # The extract and the observation it would be written to. Both have
    # to exist: an image with no observation has nothing to review into.
    def extract_or_redirect!
      @extract = FieldSlipExtract.find_by(image_id: @image.id)
      @observation = @extract&.observation
      return @observation if @observation

      flash_error(:field_slip_extract_missing.t)
      redirect_to(image_path(@image.id))
      nil
    end

    def apply_chosen_fields
      FieldSlip::Extractor::Applier.new(
        observation: @observation, chosen: chosen_fields, user: @user
      ).apply
    end

    # Only the ticked rows, keyed by slip field, holding whatever text
    # the reviewer left in the input.
    def chosen_fields
      ticked = params[:use].to_unsafe_h.select { |_k, v| v == "1" }.keys
      values = params[:value]&.to_unsafe_h || {}
      ticked.index_with { |field| values[field] }
    end
  end
end
