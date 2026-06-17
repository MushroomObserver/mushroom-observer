# frozen_string_literal: true

# Reviewer-only "export status" toggle pair. Renders the current
# state in bold and the opposite state as a link to flip the flag
# via the `ExportController` action, separated by `|`.
#
# Two flags currently use this UI: an object's `ok_for_export`
# flag (`:ok_for_export`, the default) and an Image's `diagnostic`
# flag (`:diagnostic`, used by the ML-training data pipeline).
#
# Drop-in replacement for the long-standing `export_status_controls`
# and `export_status_ml_controls` helpers in
# `app/helpers/exports_helper.rb`. Returns nothing (empty render)
# for non-reviewer viewers.
#
# @example Ok-for-export pair on a Name
#   render(Components::Image::ExportStatusControls.new(object: @name))
#
# @example ML training flag pair on an Image
#   render(Components::Image::ExportStatusControls.new(
#            object: @image, flag: :diagnostic
#          ))
class Components::Image::ExportStatusControls < Components::Base
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

  prop :object, _Union(::Name, ::NameDescription, ::Image)
  prop :flag, _Union(:ok_for_export, :diagnostic), default: :ok_for_export

  def view_template
    return unless reviewer?

    status = @object.public_send(@flag)
    config = FLAGS.fetch(@flag)
    render_current_state(status: status, config: config)
    plain(" | ")
    render_other_state(status: status, config: config)
  end

  private

  def render_current_state(status:, config:)
    if status
      b(class: "text-nowrap") { plain(config[:ok_msg].t) }
    else
      flip_link(config: config, value: 1) { plain(config[:ok_msg].t) }
    end
  end

  def render_other_state(status:, config:)
    if status
      flip_link(config: config, value: 0) { plain(config[:not_ok_msg].t) }
    else
      b(class: "text-nowrap") { plain(config[:not_ok_msg].t) }
    end
  end

  def flip_link(config:, value:, &block)
    link_to(
      add_q_param(action_params(config[:action], value)),
      class: "text-nowrap",
      &block
    )
  end

  def action_params(action, value)
    { controller: "/export", action: action,
      type: @object.type_tag, id: @object.id, value: value }
  end
end
