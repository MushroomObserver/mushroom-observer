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
#   class LicenseForm < Components::ApplicationForm
#     def view_template
#       text_field(:display_name)
#       submit
#     end
#
#     def form_action
#       model.persisted? ? view_context.license_path(model) :
#                          view_context.licenses_path
#     end
#   end
#
#   # In new.html.erb and edit.html.erb, just render the form directly:
#   <%= render(Components::LicenseForm.new(@license)) %>
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
#   <%= render(Components::NameTrackerForm.new(
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
  include FieldHelpers
  include UploadHelpers

  # Automatically set form ID based on class name unless explicitly provided
  # @param model [ActiveRecord::Base] the model object for the form
  # @param id [String] optional form ID (auto-generated from class name if nil)
  # @param local [Boolean] if true, renders non-turbo form (default: true)
  # @param options [Hash] additional options passed to Superform
  def initialize(model, id: nil, local: true, **options)
    # Generate ID from class name: Components::APIKeyForm -> "api_key_form"
    # For anonymous classes (tests), default to "application_form"
    auto_id = id || self.class.name&.demodulize&.underscore ||
              "application_form"
    @turbo_stream = !local
    super(model, **options.merge(id: auto_id))
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
  register_value_helper :url_for
  register_value_helper :rank_as_string
  register_output_helper :help_note, mark_safe: true

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
