# frozen_string_literal: true

# Base form component for all Superform forms in the application.
#
# Provides custom Bootstrap-styled field components and shared helper methods
# for building consistent form layouts with labels, help text, validation, etc.
#
# @example Basic usage
#   class UserForm < Components::ApplicationForm
#     def view_template
#       text_field(:email, label: "Email", help: "We'll never share your email")
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
# @example Custom form method logic
#   # Override form_method when you need custom HTTP method logic
#   class CustomForm < Components::ApplicationForm
#     def initialize(model, method: nil, **)
#       @method = method
#       super(model, **)
#     end
#
#     protected
#
#     def form_method
#       return super unless @method  # IMPORTANT: Always call super as fallback
#
#       @method.to_s.downcase == "get" ? "get" : "post"
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
class Components::ApplicationForm < Superform::Rails::Form
  include Phlex::Slotable

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
  register_value_helper :current_user
  register_value_helper :url_for
  register_value_helper :rank_as_string

  # We don't need to register form helpers anymore - using Superform fields

  # Wrapper option keys that should not be passed to the field itself
  WRAPPER_OPTIONS = [:label, :help, :prefs, :inline, :wrap_class, :addon,
                     :button, :button_data, :monospace].freeze

  # Override the Field class to use our custom components
  class Field < Superform::Rails::Form::Field
    def text(wrapper_options: {}, **attributes)
      TextField.new(self, attributes: attributes,
                          wrapper_options: wrapper_options)
    end

    def textarea(wrapper_options: {}, **attributes)
      TextareaField.new(self, attributes: attributes,
                              wrapper_options: wrapper_options)
    end

    def file(wrapper_options: {}, **attributes)
      FileField.new(self, attributes: attributes,
                          wrapper_options: wrapper_options)
    end

    def checkbox(wrapper_options: {}, **attributes)
      CheckboxField.new(self, attributes: attributes,
                              wrapper_options: wrapper_options)
    end

    def select(options, wrapper_options: {}, **attributes)
      SelectField.new(self, collection: options, attributes: attributes,
                            wrapper_options: wrapper_options)
    end

    def read_only(wrapper_options: {}, **attributes)
      ReadOnlyField.new(self, attributes: attributes,
                              wrapper_options: wrapper_options)
    end

    def autocompleter(type:, textarea: false, wrapper_options: {},
                      **attributes)
      AutocompleterField.new(self, type: type, textarea: textarea,
                                   attributes: attributes,
                                   wrapper_options: wrapper_options)
    end

    # Alias for backwards compatibility
    alias hidden read_only

    def static(wrapper_options: {}, **attributes)
      StaticTextField.new(self, attributes: attributes,
                                wrapper_options: wrapper_options)
    end
  end

  # Main field wrapper methods with Bootstrap styling
  # Replicates the API of the original form helpers

  # Text field with label and Bootstrap form-group wrapper
  # @param field_name [Symbol] the field name
  # @param options [Hash] all field and wrapper options
  # @option options [String,false] :label label text (optional, inferred from
  #   field name), or false to omit label
  # @option options [String] :help help text displayed below field
  # @option options [Boolean] :prefs auto-generate label from prefs translation
  # @option options [Boolean] :inline render label and field inline
  # @option options [String] :wrap_class CSS classes for wrapper div
  # @option options [String] :class CSS classes for input element
  # @option options [String] :addon text addon (static, not interactive)
  # @option options [String] :button button addon (interactive)
  # @option options [Hash] :button_data data attributes for button addon
  # All other options passed to the input element
  # @yield [field_component] Optional block to set slots with `with_between`
  #   and `with_append`
  def text_field(field_name, **options)
    wrapper_opts = options.slice(*WRAPPER_OPTIONS)
    field_opts = options.except(*WRAPPER_OPTIONS)

    field_component = field(field_name).text(
      wrapper_options: wrapper_opts,
      **field_opts
    )

    yield(field_component) if block_given?

    render(field_component)
  end

  # Textarea field with label and Bootstrap form-group wrapper
  # @param field_name [Symbol] the field name
  # @param options [Hash] all field and wrapper options
  # @option options [Boolean] :monospace add monospace font class
  # All other wrapper options same as text_field
  # @yield [field_component] Optional block to set slots with `with_between`
  #   and `with_append`
  def textarea_field(field_name, **options)
    wrapper_opts = options.slice(*WRAPPER_OPTIONS)
    field_opts = options.except(*WRAPPER_OPTIONS)

    # Handle monospace option
    if wrapper_opts.delete(:monospace)
      field_opts[:class] = class_names(field_opts[:class], "text-monospace")
    end

    field_component = field(field_name).textarea(
      wrapper_options: wrapper_opts,
      **field_opts
    )

    yield(field_component) if block_given?

    render(field_component)
  end

  # Checkbox field with label and Bootstrap checkbox wrapper
  # @param field_name [Symbol] the field name
  # @param options [Hash] all field and wrapper options
  # Wrapper options: :label, :help, :prefs, :class_name
  # @yield [field_component] Optional block to set slots with `with_between`
  #   and `with_append`
  def checkbox_field(field_name, **options)
    wrapper_opts = options.slice(*WRAPPER_OPTIONS)
    field_opts = options.except(*WRAPPER_OPTIONS)

    field_component = field(field_name).checkbox(
      wrapper_options: wrapper_opts,
      **field_opts
    )

    yield(field_component) if block_given?

    render(field_component)
  end

  # Select field with label and Bootstrap form-group wrapper
  # @param field_name [Symbol] the field name
  # @param options_list [Array] the select options
  # @param options [Hash] all field and wrapper options
  # All wrapper options same as text_field
  # @yield [field_component] Optional block to set slots with `with_between`
  #   and `with_append`
  def select_field(field_name, options_list, **options)
    wrapper_opts = options.slice(*WRAPPER_OPTIONS)
    field_opts = options.except(*WRAPPER_OPTIONS)

    field_component = field(field_name).select(
      options_list,
      wrapper_options: wrapper_opts,
      **field_opts
    )

    yield(field_component) if block_given?

    render(field_component)
  end

  # Password field with label and Bootstrap form-group wrapper
  # @param field_name [Symbol] the field name
  # @param options [Hash] all field and wrapper options
  # All wrapper options same as text_field
  # @yield [field_component] Optional block to set slots with `with_between`
  #   and `with_append`
  def password_field(field_name, **options)
    wrapper_opts = options.slice(*WRAPPER_OPTIONS)
    field_opts = options.except(*WRAPPER_OPTIONS)

    field_component = field(field_name).text(
      wrapper_options: wrapper_opts,
      type: "password",
      **field_opts
    )

    yield(field_component) if block_given?

    render(field_component)
  end

  # Hidden field (no label or wrapper)
  # @param field_name [Symbol] the field name
  # @param options [Hash] all field options
  def hidden_field(field_name, **)
    render(field(field_name).text(**, type: "hidden"))
  end

  # Number field with label and Bootstrap form-group wrapper
  # @param field_name [Symbol] the field name
  # @param options [Hash] all field and wrapper options
  # All wrapper options same as text_field
  # @yield [field_component] Optional block to set slots with `with_between`
  #   and `with_append`
  def number_field(field_name, **options)
    wrapper_opts = options.slice(*WRAPPER_OPTIONS)
    field_opts = options.except(*WRAPPER_OPTIONS)

    field_component = field(field_name).text(
      wrapper_options: wrapper_opts,
      type: "number",
      **field_opts
    )

    yield(field_component) if block_given?

    render(field_component)
  end

  # Override Superform's submit to add Bootstrap styling and turbo support
  # @param value [String] the button text (defaults to submit_value from model)
  # @param options [Hash] submit button options
  # @option options [Boolean] :center center the button (default false)
  # @option options [String] :submits_with text shown while submitting
  # @option options [String] :class additional CSS classes
  # @option options [Hash] :data additional data attributes
  def submit(value = submit_value, center: false, submits_with: nil, **options)
    submits_with ||= :SUBMITTING.l
    classes = %w[btn btn-default]
    classes << "center-block my-3" if center
    classes << options[:class] if options[:class].present?

    data = { turbo_submits_with: submits_with,
             disable_with: value }.merge(options[:data] || {})

    super(value, **options.merge(class: classes.join(" "), data: data))
  end

  # Renders image upload fields in a :upload namespace
  # Creates params[:model][:upload][image], etc. (nested under form model)
  def upload_fields(file_field_label: "#{:IMAGE.l}:",
                    file_field_between: nil, **args)
    args => {
      copyright_holder:, copyright_year:, licenses:, upload_license_id:
    }

    namespace(:upload) do |upload|
      render_upload_image_field(upload, file_field_label, file_field_between)
      render_upload_copyright_holder(upload, copyright_holder)
      render_upload_year(upload, copyright_year)
      render_upload_license(upload, licenses, upload_license_id)
    end
  end

  private

  def render_upload_image_field(upload, label, between)
    render(
      upload.field(:image).file(
        wrapper_options: { label: label, between: between }
      )
    )
  end

  def render_upload_copyright_holder(upload, holder)
    render(
      upload.field(:copyright_holder).text(
        wrapper_options: { label: "#{:image_copyright_holder.l}:",
                           inline: true },
        value: holder
      )
    )
  end

  def render_upload_year(upload, year)
    render(
      upload.field(:copyright_year).select(
        upload_year_options,
        wrapper_options: { label: "#{:WHEN.l}:", inline: true },
        selected: year
      )
    )
  end

  def render_upload_license(upload, licenses, selected_id)
    # Superform expects [value, display] but Rails returns [display, value]
    # So we need to swap them
    swapped_licenses = licenses.map { |display, value| [value, display] }

    license_select = upload.field(:license_id).select(
      swapped_licenses,
      wrapper_options: { label: "#{:LICENSE.l}:", inline: true },
      selected: selected_id
    )

    license_select.with_append do
      div(class: "help-block") do
        plain("(")
        plain(:image_copyright_warning.t)
        plain(")")
      end
    end

    render(license_select)
  end

  def upload_year_options
    (1980..Time.zone.now.year).to_a.reverse.map { |y| [y.to_s, y] }
  end
end
