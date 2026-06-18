# frozen_string_literal: true

#  ==== Modal turbo_stream dispatcher
#
#  Two helpers used by controllers whose CRUD actions write to a
#  Bootstrap modal opened by the user without unloading the page.
#  Both used to live as `shared/_modal_flash_update.erb` and
#  `shared/_modal_form_reload.erb` partials that every modal
#  controller rendered via
#  `render(partial: "shared/modal_...", locals: { identifier: ..., ... })`.
#
#  - `render_modal_flash_update(identifier)` — for actions that
#    fail validation but don't need to reload the form: just push
#    the accumulated flash into the modal's `#modal_<id>_flash`
#    div via a single `turbo_stream.update`.
#  - `render_modal_form_reload(identifier:, form_locals:)` — for
#    actions that need to fully re-render the form (e.g.
#    re-running validations against a different model state).
#    Updates the flash AND replaces the `#<id>_form` body with a
#    freshly-rendered `Components::Modal::TurboForm`.
#
module ApplicationController::ModalUpdater
  private

  def render_modal_flash_update(identifier)
    render(turbo_stream: turbo_stream.update(
      "modal_#{identifier}_flash",
      ActiveSupport::SafeBuffer.new(view_context.flash_notices_html.to_s)
    ))
  end

  def render_modal_form_reload(identifier:, form_locals:)
    render(turbo_stream: [
             turbo_stream.update(
               "modal_#{identifier}_flash",
               ActiveSupport::SafeBuffer.new(view_context.flash_notices_html.to_s)
             ),
             turbo_stream.replace(
               "#{identifier}_form",
               Components::Modal::TurboForm.render_form(
                 view_context, model: form_locals[:model],
                               form_locals: form_locals
               )
             )
           ])
  end
end
