# frozen_string_literal: true

# Base modal wrapper and single entry-point dispatcher for all
# `Components::Modal::*` components. Pass `type:` to route to a
# subclass; omit for a plain modal with slots.
#
#   # Phlex views — Kit syntax:
#   Modal(type: :confirm)
#   Modal(type: :progress_spinner)
#   Modal(type: :turbo_form, identifier: "…", title: "…",
#         user: @user, model: @record)
#
#   # Controllers — full class path (Kit not available):
#   Components::Modal.new(type: :turbo_form, identifier: "…",
#                         title: "…", user: @user, model: @record)
#
# Encapsulates the Bootstrap 3
# `modal > modal-dialog > modal-content > header / body / footer`
# nesting and the close-button / title boilerplate so callers can
# focus on the modal's content.
#
# @example simple modal with body + footer
#   render(Components::Modal.new(
#     id: "modal_thing", title: "Pick a thing", user: @user
#   )) do |m|
#     m.with_body { p { "..." } }
#     m.with_footer do
#       button(type: "submit", class: "btn btn-primary") { "OK" }
#       button(type: "button", class: "btn btn-default",
#              data: { dismiss: "modal" }) { :cancel.ti }
#     end
#   end
#
# @example auto-opening modal (e.g. server-rendered for an action)
#   render(Components::Modal.new(
#     id: "modal_resolve", title: "Confirm", user: @user, auto_open: true
#   )) do |m|
#     m.with_body { render(...) }
#   end
#
# @example form-wrapped body + footer (form spans both — submit button
#   in `.modal-footer` is naturally inside the form)
#
#   When set, `with_form_content` REPLACES `with_body` and `with_footer`.
#   The caller renders a single component (typically an ApplicationForm
#   subclass) that emits its own `<div class="modal-body">` and
#   `<div class="modal-footer">` inside the form's yield, so the form
#   tag wraps both:
#
#       <div class="modal-content">
#         <div class="modal-header">...</div>
#         <form ...>
#           <div class="modal-body">...fields...</div>
#           <div class="modal-footer">...buttons...</div>
#         </form>
#       </div>
#
#   render(Components::Modal.new(
#     id: "modal_x", title: "Edit thing", user: @user
#   )) do |m|
#     m.with_form_content { render(Components::ThingForm.new(@thing)) }
#   end
class Components::Modal < Components::Base
  include Phlex::Slotable

  prop :id, String
  prop :title, _Nilable(String), default: nil
  # Bootstrap modal-dialog size variants: "modal-dialog",
  # "modal-dialog modal-lg", "modal-dialog modal-sm".
  prop :dialog_class, String, default: "modal-dialog"
  # When `true`, the modal is shown immediately on page load
  # (server-rendered for a redirect-like response, e.g.
  # `OccurrenceResolveModal`'s auto-open pattern). Adds the
  # backdrop, the `fade in` class, and the `display: block` style.
  prop :auto_open, _Boolean, default: false
  prop :user, _Nilable(User), default: nil
  # Extra CSS class(es) appended to the modal root, e.g. `modal-form`
  # (used by `ModalTurboForm` for turbo-stream form modals).
  prop :extra_class, _Nilable(String), default: nil
  prop :extra_data, _Hash(Symbol, _Any), default: -> { {} }
  # Override the auto-generated DOM ids for the title and body
  # elements. Defaults are `<id>_title` and `<id>_body`; pass
  # explicit values when external CSS/JS/turbo-stream targets rely
  # on specific ids (e.g. `ModalTurboForm` preserves its
  # `modal_<identifier>_body` convention).
  prop :title_id, _Nilable(String), default: nil
  prop :body_id, _Nilable(String), default: nil
  # Stimulus controller wired to the modal root. Defaults to `modal`
  # (the standard show/hide controller). Override for singleton layout
  # modals with their own controllers (e.g. `confirm-modal` for the
  # Turbo confirm dialog). Multiple controllers can be passed as a
  # space-separated string.
  prop :controller, String, default: "modal"
  # Render the `.modal-header` div (close button + title). Set to
  # false for headerless modals where the "title" element lives
  # inside the body for Stimulus targeting (`ModalConfirm`) or where
  # the modal has no user-visible title at all (`ModalProgressSpinner`).
  # `aria-labelledby` is still emitted on the modal root; point it at
  # the in-body element via `title_id:`.
  prop :header, _Boolean, default: true
  # Extra CSS class(es) appended to the `.modal-body` div, e.g.
  # `"py-4"` for ModalConfirm or `"text-center"` for
  # ModalProgressSpinner. Joined with the base `"modal-body"`.
  prop :body_class, _Nilable(String), default: nil

  slot :title_content
  slot :body
  slot :footer
  # When set, REPLACES body+footer slots. Caller renders a single
  # component (typically a form) that emits its own `.modal-body` and
  # `.modal-footer` divs, so a single `<form>` tag can wrap both —
  # keeps the submit button (in `.modal-footer`) naturally inside the
  # form. See the form-wrapped example in the class docstring.
  slot :form_content

  public :title_content_slot, :body_slot, :footer_slot, :form_content_slot

  DISPATCH = {
    confirm: :Confirm,
    progress_spinner: :ProgressSpinner,
    turbo_form: :TurboForm
  }.freeze

  def self.new(**kwargs, &block)
    type_sym = kwargs[:type]&.to_sym
    if (klass_name = DISPATCH[type_sym])
      kwargs.delete(:type)
      return const_get(klass_name).new(**kwargs, &block)
    end

    if kwargs.key?(:type)
      raise(ArgumentError.new(
              "Unknown Modal type: #{kwargs[:type].inspect}. " \
              "Valid types: #{DISPATCH.keys.join(", ")}."
            ))
    end

    super
  end

  def view_template(&block)
    yield(self) if block
    render_backdrop if @auto_open
    div(id: @id, class: modal_class, role: "dialog",
        style: (@auto_open ? "display: block;" : nil),
        aria: { labelledby: resolved_title_id },
        data: modal_data) do
      div(class: @dialog_class, role: "document") do
        div(class: "modal-content") do
          render_header if @header
          render_content
        end
      end
    end
  end

  private

  def render_backdrop
    div(class: "modal-backdrop fade in")
  end

  def modal_class
    classes = ["modal"]
    classes << "fade in" if @auto_open
    classes << "fade" unless @auto_open
    classes << @extra_class if @extra_class.present?
    classes.join(" ")
  end

  def modal_data
    data = { controller: @controller }
    data[:modal_user_value] = @user.id if @user
    data.merge(@extra_data)
  end

  def resolved_title_id
    @title_id || "#{@id}_title"
  end

  def resolved_body_id
    @body_id || "#{@id}_body"
  end

  def render_header
    div(class: "modal-header") do
      close_button
      h4(class: "modal-title", id: resolved_title_id) do
        if title_content_slot
          render(title_content_slot)
        elsif @title
          # Titles often come from MO's `.t` (textilize), which returns
          # HTML-safe strings with rendered tags (`<i>`, `<b>`). Plain
          # strings get escaped — preserves the original ModalForm
          # behavior (which used `{ @title }` block emission).
          trusted_html(@title)
        end
      end
    end
  end

  def close_button
    Button(
      variant: :strip,
      class: "close",
      data: { dismiss: "modal" },
      aria: { label: :close.ti }
    ) do
      span(aria: { hidden: "true" }) { "×" }
    end
  end

  def render_content
    if form_content_slot
      render(form_content_slot)
    else
      render_body
      render_footer
    end
  end

  def render_body
    return unless body_slot

    div(class: body_classes, id: resolved_body_id) { render(body_slot) }
  end

  def body_classes
    @body_class ? "modal-body #{@body_class}" : "modal-body"
  end

  def render_footer
    return unless footer_slot

    div(class: "modal-footer") { render(footer_slot) }
  end
end
