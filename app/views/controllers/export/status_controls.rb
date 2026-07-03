# frozen_string_literal: true

module Views::Controllers::Export
  # Reviewer-only "export status" toggle pair, Turbo-updated in place.
  # Renders the current state in bold and the opposite state as a
  # PUT-method button that flips the flag via `ExportController`,
  # separated by `|`. Wrapped in a `dom_id`'d container so
  # `ExportController` can `turbo_stream.replace` it after the flip.
  #
  # Not a reusable UI primitive — it's the turbo-partial `ExportController`
  # itself re-renders on each flip, embedded as-is by the Image/Name/
  # NameDescription show pages that expose this reviewer control.
  #
  # Two flags currently use this UI: an object's `ok_for_export`
  # flag (`:ok_for_export`, the default) and an Image's `diagnostic`
  # flag (`:diagnostic`, used by the ML-training data pipeline).
  #
  # Returns nothing (empty render) for non-reviewer viewers.
  #
  # @example Ok-for-export pair on a Name
  #   render(Views::Controllers::Export::StatusControls.new(object: @name))
  #
  # @example ML training flag pair on an Image
  #   render(Views::Controllers::Export::StatusControls.new(
  #            object: @image, flag: :diagnostic
  #          ))
  class StatusControls < Views::Base
    FLAGS = {
      ok_for_export: {
        ok_msg: :review_ok_for_export,
        not_ok_msg: :review_no_export,
        action: :set_export_status
      },
      diagnostic: {
        ok_msg: :review_diagnostic,
        not_ok_msg: :review_non_diagnostic,
        action: :set_ml_status
      }
    }.freeze

    prop :object, _Union(::Name, ::NameDescription, ::Location,
                         ::LocationDescription, ::Image)
    prop :flag, _Union(:ok_for_export, :diagnostic), default: :ok_for_export

    def view_template
      return unless reviewer?

      div(id: dom_id(@object, @flag)) do
        status = @object.public_send(@flag)
        config = FLAGS.fetch(@flag)
        render_current_state(status: status, config: config)
        plain(" | ")
        render_other_state(status: status, config: config)
      end
    end

    private

    def render_current_state(status:, config:)
      if status
        b(class: "text-nowrap") { plain(config[:ok_msg].t) }
      else
        flip_button(config: config, value: 1, name: config[:ok_msg].t)
      end
    end

    def render_other_state(status:, config:)
      if status
        flip_button(config: config, value: 0, name: config[:not_ok_msg].t)
      else
        b(class: "text-nowrap") { plain(config[:not_ok_msg].t) }
      end
    end

    def flip_button(config:, value:, name:)
      Button(
        type: :put,
        name: name,
        target: action_params(config[:action], value),
        variant: :strip,
        class: "text-nowrap",
        data: { turbo: true }
      )
    end

    def action_params(action, value)
      { controller: "/export", action: action,
        type: @object.type_tag, id: @object.id, value: value }
    end
  end
end
