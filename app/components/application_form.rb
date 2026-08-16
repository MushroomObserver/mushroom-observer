# frozen_string_literal: true

# Base form component for all Superform forms in the application.
#
# Provides custom Bootstrap-styled field components and shared helper methods
# for building consistent form layouts with labels, help text, validation, etc.
#
# @example Basic usage
#   class UserForm < Components::ApplicationForm
#     def view_template
#       text_field(:email, label: "Email") do |f|
#         f.with_help { "We'll never share your email" }
#       end
#       textarea_field(:bio, label: "Bio", rows: 5)
#       checkbox_field(:terms, label: "I agree to the terms")
#       submit "Sign up"
#     end
#   end
#
# @example Deriving action URL from model (eliminates passing action from view)
#   module Views::Controllers::Licenses
#     class Form < ::Components::ApplicationForm
#       def view_template
#         text_field(:display_name)
#         submit
#       end
#
#       def form_action
#         model.persisted? ? view_context.license_path(model) :
#                            view_context.licenses_path
#       end
#     end
#   end
#
#   # In new.rb and edit.rb, just render the form directly:
#   <%= render(Views::Controllers::Licenses::Form.new(@license)) %>
#
# @example Deriving action URL from model associations
#   # For forms where the action depends on an associated model
#   class NameTrackerForm < Components::ApplicationForm
#     def view_template
#       text_field(:note_template)
#       submit
#     end
#
#     def form_action
#       # Access model associations to build the URL
#       url_for(controller: "names/trackers", action: :create,
#               id: model.name.id, only_path: true)
#     end
#   end
#
#   # In the view, no need to pass action:
#   <%= render(Views::Controllers::Names::Trackers::Form.new(
#     @name_tracker || NameTracker.new(name: @name)
#   )) %>
#
# @example HTTP method handling
#   # Superform automatically determines HTTP method based on model.persisted?
#   # - persisted? == true  → PATCH (updates)
#   # - persisted? == false → POST (creates)
#   #
#   # For FormObject classes (non-persisted by default), if you need to force
#   # PATCH/PUT, override persisted?:
#   class FormObject::AdminSession
#     def persisted?
#       true  # Forces Superform to use PATCH method
#     end
#   end
#
# @example Accessing view helpers (like in_admin_mode?)
#   class GlossaryTermForm < Components::ApplicationForm
#     def view_template
#       text_field(:name)
#       checkbox_field(:locked) if in_admin_mode?
#       submit
#     end
#   end
#
# @example When a custom `initialize` is (and isn't) needed
#   # No custom initialize needed: `model` is an object the caller
#   # already has, passed straight through as the positional arg.
#   # Every other value the view template reads is just a `prop`.
#   class NameForm < Components::ApplicationForm
#     prop :user, ::User
#   end
#   # NameForm.new(@name, user: @user)
#
#   # Custom initialize needed ("Pattern B"): the model has to be
#   # *built*, not accepted -- there's no FormObject instance sitting
#   # around in the caller to pass through. `prop`s you declare are
#   # still type-checked and assigned even though a hand-written
#   # initialize now runs -- Literal resolves properties off `self.class`,
#   # not off whichever ancestor's `initialize` happens to execute.
#   class WebmasterQuestionForm < Components::ApplicationForm
#     prop :email_error, _Nilable(_Boolean), default: nil
#
#     def initialize(_model = nil, reply_to: nil, message: nil, **)
#       form_object = FormObject::EmailRequest.new(
#         reply_to: reply_to, message: message
#       )
#       super(form_object, **)
#     end
#   end
#
#   # `email_error` is a prop because the form itself reads `@email_error`
#   # (e.g. for autofocus logic). `reply_to`/`message` are plain
#   # initialize params, not props, because nothing reads `@reply_to`/
#   # `@message` afterward -- they're forwarded once into the FormObject
#   # and read back out through Superform's normal field binding
#   # (`model.reply_to`, `text_field(:reply_to)`). Making them props too
#   # would just be a second, redundant copy that can drift from
#   # `model.reply_to`.
#   #
#   # This also isn't the place for "is this a valid email" / "is this
#   # blank" checks -- a Literal prop mismatch raises at construction
#   # (a 500), and for a well-formed request these arrive as
#   # String-or-nil, so a prop type could barely ever catch anything
#   # useful anyway. Real validation belongs on the FormObject, which
#   # already includes `ActiveModel::Model` (see `FormObject::Base`) --
#   # `validates` + `.errors` fail gracefully with a normal form
#   # re-render, and Superform's field helpers already render
#   # `model.errors[:field]` inline.
#
# @example Guarding a scalar prop sourced from raw params
#   # A prop's type check fires at construction -- a scalar param
#   # sent as a nested hash (`?commit[x]=1`) parses to an
#   # ActionController::Parameters object, not a String, and raises
#   # Literal::TypeError instead of degrading gracefully. Guard at the
#   # controller call site that reads the param, not in the form:
#   #   submit_type: params.permit(:commit)[:commit]
#   # See .claude/rules/params_to_literal_props.md for the full rule
#   # (when it applies, what to use for id/Integer coercion, when a
#   # blanket params.permit sweep is NOT warranted).
#
# Field helper methods are defined in FieldHelpers (field_helpers.rb).
# Upload helpers are in UploadHelpers (upload_helpers.rb).
class Components::ApplicationForm < Superform::Rails::Form
  include Phlex::Slotable
  include Phlex::Rails::Helpers::TurboFrameTag
  # `Components::Base` includes this; ApplicationForm subclasses
  # don't inherit from Base (they go through `Superform::Rails::Form`),
  # so we include it here too. Lets subclasses call
  # `trusted_html(:foo.t)` instead of `raw(:foo.t) # rubocop:disable
  # Rails/OutputSafety`.
  include Phlex::TrustedHtml
  include FieldHelpers
  include UploadHelpers

  # `model` stays duck-typed rather than a concrete class: it backs
  # forms across ~69 subclasses spanning ActiveRecord models,
  # FormObject::Base subclasses, and other Superform-compatible
  # objects. `model_name`/`persisted?` are exactly what
  # Superform::Rails::Form itself requires (see `key`/`resource_action`
  # below and in the gem).
  prop :model, _Interface(:model_name, :persisted?), :positional
  prop :id, _Nilable(String), default: nil
  prop :turbo, _Boolean, default: false
  # Catch-all for Superform's own `action:`/`method:` kwargs plus
  # arbitrary `<form>` HTML attributes -- extracted in
  # `after_initialize`. `method:` can't be its own named prop; it
  # would shadow `Object#method` (same landmine documented on
  # `Button::CRUDBase`'s `@method`).
  prop :attributes, _Hash(Symbol, _Any?), :**

  def derive_form_id(model)
    views_id = views_controller_form_id
    return views_id if views_id

    # `Components::FooForm` (and other non-Views classes) — use the
    # class name directly.
    class_id = self.class.name&.demodulize&.underscore
    return class_id if class_id && class_id != "form"

    # Fallback (test classes with no name, etc.): derive from model.
    model_class_form_id(model)
  end

  # For `Views::Controllers::*` classes, mirror the full controller
  # path in the id so it telegraphs where the form lives in the
  # directory tree. Each path segment is singularized; the class
  # name is appended (or replaced with "form" if the class is the
  # bare `Form`).
  #
  #   Views::Controllers::Account::APIKeys::Form
  #     → account_api_key_form
  #   Views::Controllers::Admin::Donations::ReviewForm
  #     → admin_donation_review_form
  #   Views::Controllers::Admin::BlockedIps::Manager
  #     → admin_blocked_ip_manager
  #   Views::Controllers::Names::Synonyms::Approve::Form
  #     → name_synonym_approve_form
  def views_controller_form_id
    segments = views_controller_segments
    return nil unless segments

    path_parts = segments[2..-2].map { |s| s.underscore.singularize }
    class_part = segments.last.underscore
    suffix = class_part == "form" ? "form" : class_part
    "#{path_parts.join("_")}_#{suffix}"
  end

  def views_controller_segments
    segments = self.class.name&.split("::")
    return nil unless segments && segments.length >= 4 &&
                      segments[0] == "Views" &&
                      segments[1] == "Controllers"

    segments
  end

  def model_class_form_id(model)
    return nil unless model

    name = model.class.name&.demodulize&.underscore
    name && "#{name}_form"
  end

  def around_template
    # Always set data-turbo explicitly, independent of the global
    # Turbo.config.forms.mode default.
    @attributes[:data] ||= {}
    @attributes[:data][:turbo] = @turbo ? "true" : "false"
    add_form_feedback_controller
    super
  end

  # Every non-Turbo form disables its submit buttons once submitted
  # (see form-feedback_controller.js; Turbo forms are skipped there,
  # since Turbo manages its own in-flight state). Appended so a form's
  # own Stimulus controllers keep working alongside it.
  def add_form_feedback_controller
    @attributes[:data] ||= {}
    @attributes[:data][:controller] =
      [@attributes[:data][:controller], "form-feedback"].compact.join(" ")
  end

  # Form subclasses can override form_action to derive action URLs from model
  # associations or other logic, eliminating the need to pass explicit actions

  # Register view helpers that forms might need
  # Use register_value_helper for helpers that return values (not HTML)
  register_value_helper :in_admin_mode?
  register_value_helper :pluralize

  # We don't need to register form helpers anymore - using Superform fields

  # Factory method to create a FieldProxy for image fields.
  # @param type [Symbol] :good_image or :image
  # @param image_id [Integer, String] the image ID
  # @param field_key [Symbol] the field name (:notes, :when, etc.)
  # @param value [Object] the field value
  # @return [FieldProxy] a field proxy for use with field components
  def self.image_field_proxy(type, image_id, field_key, value = nil)
    FieldProxy.image_proxy(type, image_id, field_key, value)
  end

  private

  # A subclass that declares its own `prop` gets a Literal-generated
  # `initialize` that never calls `super` -- it dead-ends before
  # reaching any hand-written `initialize` up the chain, including
  # this class's. `after_initialize` is the hook Literal calls
  # unconditionally, right after prop assignment, regardless of how
  # many prop-declaring subclasses sit in between (resolved via
  # ordinary `respond_to?` + method dispatch, not baked into the
  # generated code) -- see
  # .claude/local/application_form_literal_props_superform_integration.md
  # for the full mechanism writeup.
  #
  # This replicates `Superform::Rails::Form#initialize`'s own body
  # (`@namespace = Namespace.root(...)` etc.) by hand, since that
  # method is now permanently unreachable via `super` from any
  # prop-declaring subclass.
  def after_initialize
    @action = @attributes.delete(:action)
    @method = @attributes.delete(:method)
    # Auto-derive a form id. Prefer the form class name when it's
    # specific (`Components::NameForm` -> "name_form";
    # `Components::NamePropagateLifeformForm` ->
    # "name_lifeform_propagate_form" — multiple Name-model forms
    # need distinct ids). For post-move `Views::Controllers::*::Form`
    # classes the class name yields just "form", so derive the id
    # from the controller segment of the namespace instead
    # (`Views::Controllers::Comments::Form` -> parent "Comments" ->
    # "comment_form"). Ultimately fall back to "application_form"
    # for anonymous test classes with no name and no model.
    @attributes[:id] = @id || derive_form_id(@model) || "application_form"
    @namespace = Superform::Namespace.root(key, object: @model, form: self)
  end
end
