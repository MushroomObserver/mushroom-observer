# frozen_string_literal: true

# Bootstrap modal wrapper for forms.
# Used in turbo_stream responses from `new` and `edit` form actions.
#
# The modal listens for section-update:updated events to auto-close when
# the page section is successfully updated. The user_id comparison ensures
# broadcasts don't unintentionally close other users' modals.
#
# If form submit fails, the flash and form are updated via turbo-stream
# targeting modal_{identifier}_flash and {identifier}_form.
#
# Usage:
#   render(Components::ModalForm.new(
#     identifier: "sequence",
#     title: "Add Sequence",
#     user: @user,
#     model: @sequence,
#     observation: @observation
#   ))
#
class Components::ModalForm < Components::Base
  prop :identifier, String
  prop :title, String
  prop :user, User
  prop :model, _Nilable(_Any), default: nil
  prop :observation, _Nilable(Observation), default: nil
  prop :back, _Nilable(String), default: nil
  prop :form_locals, Hash, default: -> { {} }

  # Class methods for rendering form components.
  # Used by both this component and _modal_form_reload.erb partial.
  #
  # These exist so we don't duplicate the logic for:
  #   1. Deriving the form component class from the model
  #      (e.g., Comment -> CommentForm)
  #   2. Rendering the component with the correct params
  #
  # The reload partial calls these directly since it doesn't have a
  # ModalForm instance.

  # Returns the form component class for a given model.
  # e.g., Comment -> Components::CommentForm
  def self.form_component_class_for(model)
    model_name = model.class.name.demodulize
    "Components::#{model_name}Form".constantize
  end

  # Renders the form component for a model.
  #
  # @param view_context [ActionView::Base] The view context from the calling
  #   template. In ERB, this is `self`. Needed because Phlex components must
  #   be rendered through Rails' render method, which requires a view context.
  # @param model [ActiveRecord::Base] The model instance for the form.
  # @param form_locals [Hash] Additional params to pass to the form component.
  # @return [String] The rendered HTML.
  def self.render_form(view_context, model:, form_locals: {})
    component_class = form_component_class_for(model)
    params = form_locals.except(:model).merge(local: false)
    view_context.render(component_class.new(model, **params))
  end

  def view_template
    div(**modal_attributes) do
      div(class: "modal-dialog modal-lg", role: "document") do
        div(class: "modal-content") do
          render_header
          render_body
        end
      end
    end
  end

  private

  def modal_attributes
    {
      class: "modal modal-form",
      id: "modal_#{@identifier}",
      role: "dialog",
      aria: { labelledby: "modal_#{@identifier}_header" },
      data: modal_data
    }
  end

  def modal_data
    {
      controller: "modal",
      modal_user_value: @user.id,
      action: "section-update:updated@window->modal#remove",
      identifier: @identifier
    }
  end

  def render_header
    div(class: "modal-header") do
      close_button
      h4(class: "modal-title", id: "modal_#{@identifier}_header") { @title }
    end
  end

  def close_button
    button(
      type: :button,
      class: "close",
      data: { dismiss: "modal" },
      aria: { label: :CLOSE.l }
    ) do
      span(aria: { hidden: "true" }) { "×" }
    end
  end

  def render_body
    div(class: "modal-body", id: "modal_#{@identifier}_body") do
      div(id: "modal_#{@identifier}_flash")
      render_form_component if @model
    end
  end

  def render_form_component
    self.class.render_form(self, model: @model, form_locals: merged_locals)
  end

  def merged_locals
    locals = @form_locals.dup
    locals[:observation] = @observation if @observation
    locals[:back] = @back if @back
    locals
  end
end
