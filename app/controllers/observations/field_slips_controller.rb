# frozen_string_literal: true

module Observations
  # Attach this Observation to a FieldSlip by code, from the
  # observation's own show page. Reuses the code-validate-and-attach
  # logic already used by the full observation create/update forms.
  class FieldSlipsController < ApplicationController
    include ::ObservationsController::FieldSlips
    include ::FieldSlipProjectJoinable

    before_action :login_required

    def edit
      return unless attachable_or_redirect?

      render_edit_view
    end

    def update
      return unless attachable_or_redirect?

      validate_field_slip
      if @any_errors
        render_edit_view_invalid(field_code: field_code)
        return
      end

      dispatch_update_field_slip
    end

    private

    # This page's whole purpose is attaching a code when there isn't
    # one yet -- an already-attached observation has nothing here to
    # do (and a blank submit would otherwise silently detach the
    # existing slip via clear_field_slip, see ObservationsController::
    # FieldSlips#update_field_slip).
    def attachable_or_redirect?
      return false unless (@observation = find_observation!)
      return true if permission!(@observation) && no_field_slip_yet?

      redirect_to(permanent_observation_path(@observation.id))
      false
    end

    def no_field_slip_yet?
      return true unless @observation.field_slip

      flash_warning(:observation_field_slip_already_attached.t(
                      code: @observation.field_slip.code
                    ))
      false
    end

    def find_observation!
      find_or_goto_index(Observation, params[:id])
    end

    def render_edit_view(field_code: nil, **render_opts)
      render(
        Views::Controllers::Observations::FieldSlips::Edit.new(
          observation: @observation, field_code: field_code
        ),
        **render_opts
      )
    end

    # `assign_field_slip` already flashes on a brand-new code
    # (`:field_slip_created`); an existing code has no other flash in
    # this standalone flow, so it's added here.
    def dispatch_update_field_slip
      case update_field_slip
      when :invalid
        add_field_slip_error(
          :observation_field_slip_invalid.t(code: field_code)
        )
      when :too_many
        add_field_slip_error(:observation_field_slip_full.t(
                               code: field_code,
                               max: Occurrence::MAX_OBSERVATIONS
                             ))
      when :unchanged
        add_field_slip_error(:observation_field_slip_blank.t)
      when :assigned_existing
        flash_attached_field_slip
      end
      redirect_to_observation_or_reload
    end

    def flash_attached_field_slip
      flash_notice(:field_slip_attached.t(code: field_code))
    end

    def redirect_to_observation_or_reload
      if @any_errors
        render_edit_view_invalid(field_code: field_code)
      else
        redirect_to(permanent_observation_path(@observation.id))
      end
    end
  end
end
