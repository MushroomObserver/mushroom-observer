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

  # Automatically derive a form id from the class unless one is
  # explicitly provided. See `derive_form_id` for the rule.
  # @param model [ActiveRecord::Base] the model object for the form
  # @param id [String] optional form ID
  # @param local [Boolean] if true, renders non-turbo form (default: true)
  # @param options [Hash] additional options passed to Superform
  def initialize(model, id: nil, local: true, **options)
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
    auto_id = id || derive_form_id(model) || "application_form"
    @turbo_stream = !local
    super(model, **options.merge(id: auto_id))
  end

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
    # Set turbo data attribute for turbo_stream forms
    if @turbo_stream
      @attributes[:data] ||= {}
      @attributes[:data][:turbo] = "true"
    end
    super
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
end
