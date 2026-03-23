# frozen_string_literal: true

# Bootstrap modal wrapper for the project membership confirmation.
# Auto-opens on page load with a static backdrop.
class Components::OccurrenceResolveModal < Components::Base
  def initialize(gaps:, primary:, user:, selected: nil,
                 occurrence: nil)
    super()
    @gaps = gaps
    @primary = primary
    @user = user
    @selected = selected
    @occurrence = occurrence
  end

  def view_template
    div(class: "modal-backdrop fade in")
    div(
      class: "modal fade in",
      id: "modal_resolve_projects",
      role: "dialog",
      style: "display: block;",
      data: {
        controller: "modal",
        modal_user_value: @user&.id
      }
    ) do
      div(class: "modal-dialog modal-lg", role: "document") do
        div(class: "modal-content") do
          render_header
          render_body
        end
      end
    end
  end

  private

  def render_header
    div(class: "modal-header") do
      button(type: :button, class: "close",
             data: { dismiss: "modal" },
             aria: { label: :CLOSE.l }) do
        span(aria: { hidden: "true" }) { safe("&times;") }
      end
      h4(class: "modal-title") do
        :occurrence_resolve_projects_title.l
      end
    end
  end

  def render_body
    div(class: "modal-body") do
      render(Components::OccurrenceResolveForm.new(
               gaps: @gaps, primary: @primary,
               selected: @selected, occurrence: @occurrence
             ))
    end
  end
end
