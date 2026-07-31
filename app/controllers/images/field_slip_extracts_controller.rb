# frozen_string_literal: true

module Images
  # Machine-reads a field slip photo and lets a site admin review the
  # result before any of it reaches the observation (see
  # FieldSlip::Extractor).
  #
  # Open to site admins and to admins of a project the image's
  # observations belong to (see `FieldSlipExtract.permitted?`), not to
  # everyone: each call costs money and roughly a third of fields need
  # correcting, so this wants people who know what a slip should say.
  # `create` always re-reads -- extraction changes over time and a fresh
  # read is the point of pressing the button again.
  class FieldSlipExtractsController < ApplicationController
    before_action :login_required
    before_action :find_image!
    before_action :permission_required

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
      outcome = propose_name
      # An unrecognized or ambiguous name needs the reviewer to confirm
      # before a Name is created, so the page comes back with the
      # resolver's feedback. The field writes above already landed --
      # re-running them on the resubmit is a no-op, since the values are
      # then identical.
      return rerender_for_name_approval(outcome) if outcome.needs_approval?

      flash_extract_saved(outcome)
      redirect_to(permanent_observation_path(@observation.id))
    end

    private

    # No return value: a `before_action` halts the chain when it
    # redirects, so signalling with true/false would be decoration.
    # Runs after `find_image!` because the permission depends on the
    # image's observations, not just on the user.
    def permission_required
      return unless @image
      return if FieldSlipExtract.permitted?(image: @image, user: @user,
                                            site_admin: in_admin_mode?)

      flash_error(:permission_denied.t)
      redirect_to(image_path(@image.id))
    end

    def find_image!
      @image = Image.safe_find(params[:image_id])
      return @image if @image

      flash_error(:runtime_object_not_found.t(type: :image,
                                              id: params[:image_id]))
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

    # Only when the reviewer ticked it. Unticked means "the slip says
    # this, don't propose it" -- the box starts clear for a name MO
    # doesn't hold, so creating one is always a deliberate choice.
    def propose_name
      unless params.dig(:use, FieldSlip::Extractor::NAME_FIELD) == "1"
        return FieldSlip::Extractor::NameProposer::Outcome.new(
          status: :none, naming: nil, feedback: {}
        )
      end

      FieldSlip::Extractor::NameProposer.new(
        observation: @observation, user: @user, vote: params[:vote],
        name_params: {
          given_name: params.dig(:value, FieldSlip::Extractor::NAME_FIELD),
          approved_name: params[:approved_name],
          chosen_name: params.dig(:chosen_name, :name_id)
        }
      ).propose
    end

    def flash_extract_saved(outcome)
      flash_notice(:field_slip_extract_saved.t)
      return unless outcome.proposed?

      flash_notice(:field_slip_extract_name_proposed.t(
                     name: outcome.naming.name.text_name
                   ))
    end

    def rerender_for_name_approval(outcome)
      outcome.feedback.each do |ivar, value|
        instance_variable_set(:"@#{ivar}", value)
      end
      flash_warning(:field_slip_extract_name_needs_approval.t)
      render(Views::Controllers::Images::FieldSlipExtracts::Edit.new(
               extract: @extract, observation: @observation, user: @user,
               name_feedback: outcome.feedback,
               given_name: params.dig(:value,
                                      FieldSlip::Extractor::NAME_FIELD).to_s
             ))
    end

    def apply_chosen_fields
      FieldSlip::Extractor::Applier.new(
        observation: @observation, chosen: chosen_fields, user: @user,
        inat_code: params[:inat] == "1"
      ).apply
    end

    # Only the ticked rows, keyed by slip field, holding whatever text
    # the reviewer left in the input.
    # Both hashes can be absent entirely -- Rails drops an empty one, so
    # a form submitted with nothing ticked arrives without `use` at all.
    def chosen_fields
      ticked = (params[:use]&.to_unsafe_h || {}).
               select { |_k, v| v == "1" }.keys -
               [FieldSlip::Extractor::NAME_FIELD]
      values = params[:value]&.to_unsafe_h || {}
      ticked.index_with { |field| values[field] }
    end
  end
end
