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

    # Enqueues the read (see ExtractFieldSlipJob) and lands on the
    # review page, which shows its progress -- the ~15s provider call
    # used to run right here behind a spinnerless request. Also the
    # retry path when a read failed.
    def create
      ExtractFieldSlipJob.request(image: @image, user: @user)
      redirect_to(edit_image_field_slip_extract_path(@image.id))
    end

    # Three states: a completed extract renders the review form; a
    # pending or failed one renders the self-refreshing Status page;
    # no extract at all is only worth waiting on when the caller said
    # so (`await=1`, set by the observation-create redirect while the
    # QR jobs are still attaching the slip and starting the read).
    def edit
      @extract = FieldSlipExtract.find_by(image_id: @image.id)
      return render_status unless @extract&.complete?
      return unless extract_or_redirect!

      # No `layout:` option -- `Views::FullPageBase#around_template`
      # picks the wrapping layout itself (see ApplicationController).
      render(Views::Controllers::Images::FieldSlipExtracts::Edit.new(
               extract: @extract, observation: @observation, user: @user
             ))
    end

    def update
      return unless extract_or_redirect!

      attach_ticked_code
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
      return if awaiting_own_upload?

      flash_error(:permission_denied.t)
      redirect_to(image_path(@image.id))
    end

    # The observation-create redirect can land here BEFORE the QR jobs
    # have filed the observation into its project -- at which point
    # `permitted?` has no project to check against. Waiting on your own
    # freshly uploaded photo shows nothing but a status panel, so it
    # only needs ownership; the review form itself stays behind
    # `permitted?`, which holds by the time the extract completes.
    def awaiting_own_upload?
      return false unless request.get?
      return false if FieldSlipExtract.find_by(image_id: @image.id)&.complete?

      @image.observations.any? { |obs| obs.user_id == @user.id }
    end

    def find_image!
      @image = Image.safe_find(params[:image_id])
      return @image if @image

      flash_error(:runtime_object_not_found.t(type: :image,
                                              id: params[:image_id]))
      redirect_to(images_path)
      nil
    end

    # A pending or failed extract always shows its status; a missing
    # one only does while the create redirect said to wait for the QR
    # jobs -- otherwise a bare visit keeps today's "nothing to review"
    # behavior.
    def render_status
      if @extract.nil? && params[:await].blank?
        flash_error(:field_slip_extract_missing.t)
        return redirect_to(image_path(@image.id))
      end

      render(Views::Controllers::Images::FieldSlipExtracts::Status.new(
               image: @image, extract: @extract, user: @user
             ))
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

    # The extract's template names the fields, so the same review works
    # whichever layout the slip was printed on.
    def name_field
      @extract.template.name_field
    end

    # Only when the reviewer ticked it. Unticked means "the slip says
    # this, don't propose it" -- the box starts clear for a name MO
    # doesn't hold, so creating one is always a deliberate choice.
    def propose_name
      unless params.dig(:use, name_field) == "1"
        return FieldSlip::Extractor::NameProposer::Outcome.new(
          status: :none, naming: nil, feedback: {}
        )
      end

      FieldSlip::Extractor::NameProposer.new(
        observation: @observation, user: @user, vote: params[:vote],
        name_params: {
          given_name: params.dig(:value, name_field),
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
      flash_warning(:field_slip_extract_name_needs_approval.t)
      render(Views::Controllers::Images::FieldSlipExtracts::Edit.new(
               extract: @extract, observation: @observation, user: @user,
               name_feedback: outcome.feedback,
               given_name: params.dig(:value, name_field).to_s
             ))
    end

    def apply_chosen_fields
      FieldSlip::Extractor::Applier.new(
        observation: @observation, chosen: chosen_fields, user: @user,
        template: @extract.template, inat_code: params[:inat] == "1"
      ).apply
    end

    # A ticked code row attaches the slip -- the manual path for what
    # ExtractFieldSlipJob#attach_read_code couldn't decide on its own
    # (an in-use slip resolved by hand, a corrected misread). Runs
    # before the field writes so the observation joins its project
    # first and the project's aliases apply to them.
    def attach_ticked_code
      code_field = @extract.template.code_field
      return unless params.dig(:use, code_field) == "1"
      return unless @observation.occurrence_id.nil?

      code = params.dig(:value, code_field).to_s.strip
      return if code.blank?

      result = FieldSlip::Attacher.attach(observation: @observation,
                                          code: code, user: @user)
      flash_attach_result(code, result)
    end

    def flash_attach_result(code, result)
      if result == :attached
        flash_notice(:field_slip_created.t(code: code))
        @observation.reload
      else
        flash_warning(:field_slip_extract_attach_failed.t(
                        code: code, reason: result.to_s.tr("_", " ")
                      ))
      end
    end

    # Only the ticked rows, keyed by slip field, holding whatever text
    # the reviewer left in the input.
    # Both hashes can be absent entirely -- Rails drops an empty one, so
    # a form submitted with nothing ticked arrives without `use` at all.
    def chosen_fields
      ticked = (params[:use]&.to_unsafe_h || {}).
               select { |_k, v| v == "1" }.keys - [name_field]
      values = params[:value]&.to_unsafe_h || {}
      ticked.index_with { |field| values[field] }
    end
  end
end
