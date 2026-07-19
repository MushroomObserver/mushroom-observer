# frozen_string_literal: true

# Bootstrap modal wrapper specialized for **turbo-stream form** flows.
# Controllers respond to `new`/`edit` (or other CRUD actions) with
# `format.turbo_stream { render(Components::Modal::TurboForm.new(...)) }`,
# and the result is injected into the page's `#modal_form` slot by
# turbo. Two pieces of behavior set this apart from the general
# `Components::Modal`:
#
#   - Auto-close: the modal listens for `section-update:updated`
#     window events and removes itself when the underlying page
#     section successfully re-renders. Driven by the `modal`
#     Stimulus controller's `remove` action.
#   - In-modal flash + form swap: a `modal_<identifier>_flash` div
#     inside the body catches validation flash via turbo-stream
#     updates on submit failure (see `_modal_form_reload.erb`),
#     while the form section (id `<identifier>_form`) is replaced
#     with a re-rendered form carrying the model's error state.
#
# If you don't need either of those — you just want a Bootstrap
# modal with arbitrary content — use `Components::Modal` directly.
# This component is for the controller-rendered turbo-stream form
# pattern only.
#
# @example controller
#   render(Components::Modal::TurboForm.new(
#     identifier: "sequence",
#     title: "Add Sequence",
#     user: @user,
#     model: @sequence,
#     observation: @observation
#   ), layout: false)
class Components::Modal::TurboForm < Components::Base
  prop :identifier, String
  prop :title, String
  prop :user, User
  prop :model, _Nilable(_Union(::AbstractModel, ::FormObject::Base)),
       default: nil
  prop :observation, _Nilable(Observation), default: nil
  prop :back, _Nilable(String), default: nil
  prop :form_locals, _Hash(Symbol, _Any?), default: -> { {} }
  prop :form_class, _Nilable(Class), default: nil

  # Returns the form view/component class for a given model. Prefers
  # the post-move `Views::Controllers::<Controller>::Form` location,
  # using the caller's `controller_path` so namespaced controllers
  # like `projects/members` map to `Views::Controllers::Projects::Members::Form`.
  # Falls back to model-based derivation when no controller_path is
  # given, then to the legacy `Components::<Model>Form`.
  # See `.claude/rules/phlex_reference.md` for the move rule.
  def self.form_component_class_for(model, controller_path: nil)
    if controller_path
      klass = "Views::Controllers::#{controller_path.camelize}::Form".
              safe_constantize
      return klass if klass
    end
    model_name = model.class.name.demodulize
    "Views::Controllers::#{model_name.tableize.camelize}::Form".
      safe_constantize ||
      "Components::#{model_name}Form".constantize
  end

  # Renders the form component for a model. Used here and by
  # `_modal_form_reload.erb` (which only has a view context, not a
  # `ModalTurboForm` instance, so it calls this class method).
  #
  # The parameter is the template's `self` — an ActionView context
  # when called from an ERB partial. Named `template` rather than
  # `view_context` so the
  # `no_helpers_in_phlex_views_test` / on-save guard against
  # `view_context.foo` calls inside Phlex view code doesn't trip on
  # this class-method utility, where the value really IS the
  # caller's view context (not a Phlex `view_context` dispatch).
  #
  # @param template [ActionView::Base] view context from the
  #   calling ERB template (`self` in the ERB)
  # @param model [ActiveRecord::Base] the model instance for the form
  # @param form_locals [Hash] additional params passed to the form
  # @return [String] the rendered HTML
  def self.render_form(template, model:, form_locals: {})
    component_class = form_component_class_for(
      model, controller_path: template.try(:controller_path)
    )
    params = form_locals.except(:model).merge(local: false)
    template.render(component_class.new(model, **params))
  end

  def view_template
    Modal(
      id: modal_id,
      title: @title,
      dialog_class: "modal-dialog modal-lg",
      user: @user,
      extra_class: "modal-form",
      extra_data: turbo_modal_data,
      # Preserve the pre-refactor DOM-id convention. External
      # CSS/JS and turbo-stream re-renders may target these by
      # name (`modal_<identifier>_header`, `_body`).
      title_id: "#{modal_id}_header",
      body_id: "#{modal_id}_body"
    ) do |m|
      if form_owns_modal_sections?
        m.with_form_content { render_form_component }
      else
        m.with_body { render_body_contents }
      end
    end
  end

  private

  # A form class can opt into rendering its own `.modal-body` and
  # `.modal-footer` divs (so the `<form>` spans both — submit in the
  # footer is naturally inside the form) by declaring a class method
  # `owns_modal_sections?` returning truthy. This auto-detection
  # keeps the controller call site unchanged when migrating a form.
  def form_owns_modal_sections?
    @form_class.respond_to?(:owns_modal_sections?) &&
      @form_class.owns_modal_sections?
  end

  def modal_id
    "modal_#{@identifier}"
  end

  def turbo_modal_data
    {
      action: "section-update:updated@window->modal#remove",
      identifier: @identifier
    }
  end

  def render_body_contents
    div(id: "modal_#{@identifier}_flash")
    render_form_component if @model
  end

  def render_form_component
    if @form_class
      params = merged_locals.except(:model).merge(local: false)
      params[:modal_ids] = modal_ids if form_owns_modal_sections?
      render(@form_class.new(@model, **params))
    else
      self.class.render_form(self, model: @model, form_locals: merged_locals)
    end
  end

  # When the form owns its own `.modal-body` / `.modal-footer` divs,
  # it needs the id for `.modal-body` (so external turbo-streams can
  # target it) and the id of the flash slot inside the body.
  def modal_ids
    { body: "#{modal_id}_body", flash: "#{modal_id}_flash" }
  end

  def merged_locals
    locals = @form_locals.dup
    locals[:observation] = @observation if @observation
    locals[:back] = @back if @back
    locals
  end
end
