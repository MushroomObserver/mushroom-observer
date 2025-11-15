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
# @example Auto-determining action URL (eliminates _form.html.erb partials)
#   class LicenseForm < Components::ApplicationForm
#     def view_template
#       text_field(:display_name)
#       submit
#     end
#
#     private
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
# @example Accessing view helpers (like in_admin_mode?)
#   class GlossaryTermForm < Components::ApplicationForm
#     def view_template
#       text_field(:name)
#       checkbox_field(:locked) if show_locked_field?
#       submit
#     end
#
#     private
#
#     def show_locked_field?
#       view_helper(:in_admin_mode?)
#     end
#   end
# rubocop:disable Metrics/ClassLength
class Components::ApplicationForm < Superform::Rails::Form
  include Phlex::Slotable

  # Override initialize to store whether we need to auto-determine action
  # Form subclasses can define private form_action to customize behavior
  def initialize(model, action: nil, **)
    @auto_determine_action = action.nil? && respond_to?(:form_action, true)
    super
  end

  # Override around_template to set action before rendering if needed
  def around_template
    # Determine action now that helpers are available
    @action = form_action if @auto_determine_action && @action.nil?
    super
  end

  # Access view helpers like in_admin_mode?, current_user, etc.
  # Delegates to view_context since helpers. is deprecated
  #
  # @example
  #   def show_admin_fields?
  #     admin_mode?
  #   end
  #
  #   def admin_mode?
  #     view_helper(:in_admin_mode?)
  #   end
  def view_helper(helper_name, ...)
    view_context.public_send(helper_name, ...)
  end

  # Define slots for field wrappers
  slot :between
  slot :append

  # Wrapper option keys that should not be passed to the field itself
  WRAPPER_OPTIONS = [:label, :help, :prefs, :inline, :class_name, :addon,
                     :button, :button_data, :monospace, :between,
                     :append].freeze

  # Custom Bootstrap text input component
  class TextField < Superform::Rails::Components::Input
    include Phlex::Rails::Helpers::ClassNames

    def view_template
      input(**attributes, class: class_names(attributes[:class],
                                             "form-control"))
    end
  end

  # Custom Bootstrap textarea component
  class TextareaField < Superform::Rails::Components::Textarea
    include Phlex::Rails::Helpers::ClassNames

    def view_template(&content)
      content ||= proc { field.dom.value }
      textarea(**attributes, class: class_names(attributes[:class],
                                                "form-control"), &content)
    end
  end

  # Custom Bootstrap checkbox component
  class CheckboxField < Superform::Rails::Components::Checkbox
    # Inherits proper checkbox behavior from Superform (hidden input + checked)
  end

  # Custom Bootstrap select component
  class SelectField < Superform::Rails::Components::Select
    include Phlex::Rails::Helpers::ClassNames

    def view_template(&options_block)
      if options_block
        select(**attributes, class: class_names(attributes[:class],
                                                "form-control"), &options_block)
      else
        select(**attributes, class: class_names(attributes[:class],
                                                "form-control")) do
          options(*@collection)
        end
      end
    end
  end

  # Override the Field class to use our custom components
  class Field < Superform::Rails::Form::Field
    def text(**attributes)
      TextField.new(self, attributes: attributes)
    end

    def textarea(**attributes)
      TextareaField.new(self, attributes: attributes)
    end

    def checkbox(**attributes)
      CheckboxField.new(self, attributes: attributes)
    end

    def select(options, **attributes)
      SelectField.new(self, collection: options, attributes: attributes)
    end
  end

  # Main field wrapper methods with Bootstrap styling
  # Replicates the API of the original form helpers

  # Text field with label and Bootstrap form-group wrapper
  # @param field_name [Symbol] the field name
  # @param options [Hash] all field and wrapper options
  # @option options [String] :label label text (optional, inferred from field)
  # @option options [String] :help help text displayed below field
  # @option options [Boolean] :prefs auto-generate label from prefs translation
  # @option options [Boolean] :inline render label and field inline
  # @option options [Symbol] :between shorthand for optional/required
  # @option options [Symbol] :append shorthand for optional/required
  # @option options [String] :class_name additional CSS classes for wrapper
  # @option options [String] :addon text addon (static, not interactive)
  # @option options [String] :button button addon (interactive)
  # @option options [Hash] :button_data data attributes for button addon
  # All other options passed to the input element
  def text_field(field_name, **options)
    wrapper_opts = options.slice(*WRAPPER_OPTIONS)
    field_opts = options.except(*WRAPPER_OPTIONS)

    wrap_field(
      field(field_name).text(**field_opts),
      **wrapper_opts
    )
  end

  # Textarea field with label and Bootstrap form-group wrapper
  # @param field_name [Symbol] the field name
  # @param options [Hash] all field and wrapper options
  # @option options [Boolean] :monospace add monospace font class
  # All other wrapper options same as text_field
  def textarea_field(field_name, **options)
    wrapper_opts = options.slice(*WRAPPER_OPTIONS)
    field_opts = options.except(*WRAPPER_OPTIONS)

    # Handle monospace option
    if wrapper_opts.delete(:monospace)
      field_opts[:class] = class_names(field_opts[:class], "text-monospace")
    end

    wrap_field(
      field(field_name).textarea(**field_opts),
      **wrapper_opts
    )
  end

  # Checkbox field with label and Bootstrap checkbox wrapper
  # @param field_name [Symbol] the field name
  # @param options [Hash] all field and wrapper options
  # Wrapper options: :label, :help, :prefs, :between, :append, :class_name
  def checkbox_field(field_name, **options)
    wrapper_opts = options.slice(*WRAPPER_OPTIONS)
    field_opts = options.except(*WRAPPER_OPTIONS)

    wrap_checkbox(
      field(field_name).checkbox(**field_opts),
      **wrapper_opts
    )
  end

  # Select field with label and Bootstrap form-group wrapper
  # @param field_name [Symbol] the field name
  # @param options_list [Array] the select options
  # @param options [Hash] all field and wrapper options
  # All wrapper options same as text_field
  def select_field(field_name, options_list, **options)
    wrapper_opts = options.slice(*WRAPPER_OPTIONS)
    field_opts = options.except(*WRAPPER_OPTIONS)

    wrap_field(
      field(field_name).select(options_list, **field_opts),
      **wrapper_opts
    )
  end

  # Password field with label and Bootstrap form-group wrapper
  # @param field_name [Symbol] the field name
  # @param options [Hash] all field and wrapper options
  # All wrapper options same as text_field
  def password_field(field_name, **options)
    wrapper_opts = options.slice(*WRAPPER_OPTIONS)
    field_opts = options.except(*WRAPPER_OPTIONS)

    wrap_field(
      field(field_name).text(**field_opts, type: "password"),
      **wrapper_opts
    )
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
  def number_field(field_name, **options)
    wrapper_opts = options.slice(*WRAPPER_OPTIONS)
    field_opts = options.except(*WRAPPER_OPTIONS)

    wrap_field(
      field(field_name).text(**field_opts, type: "number"),
      **wrapper_opts
    )
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

  private

  # Wrap a field component with Bootstrap form-group and label
  # rubocop:disable Metrics/AbcSize
  def wrap_field(field_component, **options)
    opts = process_field_options(field_component, **options)

    inline = options[:inline] || false
    class_name = options[:class_name]
    addon = options[:addon]
    button = options[:button]
    button_data = options[:button_data] || {}

    # Build wrapper
    div(class: form_group_wrap_class("form-group", inline, class_name)) do
      render_label_row(
        field_component.field,
        opts[:label_text],
        inline,
        opts[:between]
      )
      render_field_input(field_component, addon, button, button_data)
      render_append_content(opts[:append]) if opts[:append].present?
    end
  end
  # rubocop:enable Metrics/AbcSize

  # rubocop:disable Metrics/AbcSize
  def process_field_options(field_component, **options)
    label = options[:label]
    prefs = options[:prefs] || false
    help = options[:help]
    inline = options[:inline] || false
    between = options[:between]
    append = options[:append]

    between, append = process_optional_required(between, append)

    if help.present?
      between, append = add_help_block(
        field_component.field,
        between: between,
        append: append,
        help: help,
        inline: inline
      )
    end

    label_text = get_label_text(field_component.field.key, label, prefs)

    { label_text: label_text, between: between, append: append }
  end
  # rubocop:enable Metrics/AbcSize

  def render_field_input(field_component, addon, button, button_data)
    if addon.present?
      render_field_with_addon(field_component, addon)
    elsif button.present?
      render_field_with_button(field_component, button, button_data)
    else
      render(field_component)
    end
  end

  # Wrap a checkbox with Bootstrap checkbox styling
  def wrap_checkbox(field_component, **options)
    opts = process_checkbox_options(field_component, **options)
    class_name = options[:class_name]

    # Build checkbox wrapper
    div(class: form_group_wrap_class("checkbox", false, class_name)) do
      render_checkbox_label(field_component, opts[:label_text], opts[:between])
      render_append_content(opts[:append]) if opts[:append].present?
    end
  end

  def process_checkbox_options(field_component, **options)
    label = options[:label]
    prefs = options[:prefs] || false
    help = options[:help]
    between = options[:between]
    append = options[:append]

    between, append = process_optional_required(between, append)

    if help.present?
      between, append = add_help_block(
        field_component.field,
        between: between,
        append: append,
        help: help,
        inline: false
      )
    end

    label_text = get_label_text(field_component.field.key, label, prefs)

    { label_text: label_text, between: between, append: append }
  end

  def render_checkbox_label(field_component, label_text, between)
    label(for: field_component.field.dom.id) do
      render(field_component)
      plain(" #{label_text}")
      render_between_content(between) if between.present?
    end
  end

  # Render label row with optional between content
  def render_label_row(field, label_text, inline, between)
    display = inline ? "d-inline-flex" : "d-flex"

    div(class: "#{display} justify-content-between") do
      div do
        label(for: field.dom.id, class: "mr-3") { label_text }
        render_between_content(between) if between.present?
      end
    end
  end

  # Render between content (can be a symbol, hash, or plain value)
  def render_between_content(between)
    case between
    when Hash
      # Hash with help trigger info
      span(class: between[:class]) do
        render_between_content(between[:content]) if between[:content].present?
        CollapseInfoTrigger(target_id: between[:help_id])
      end
    when Symbol
      # :optional or :required shorthand
      span(class: "help-note mr-3") { "(#{between.l})" }
    else
      # Plain text
      plain(between.to_s)
    end
  end

  # Render append content (can be a symbol, hash, or plain value)
  def render_append_content(append)
    case append
    when Hash
      # Hash with help block info
      render_append_content(append[:content]) if append[:content].present?
      CollapseHelpBlock(target_id: append[:help_id]) do
        append[:help_text]
      end
    when Symbol
      # :optional or :required shorthand
      span(class: "help-note mr-3") { "(#{append.l})" }
    else
      # HTML-safe string or plain text
      if append.respond_to?(:html_safe?) && append.html_safe?
        append
      else
        plain(append.to_s)
      end
    end
  end

  # Render field with text addon
  def render_field_with_addon(field_component, addon_text)
    div(class: "input-group") do
      render(field_component)
      span(class: "input-group-addon") { addon_text }
    end
  end

  # Render field with button addon
  def render_field_with_button(field_component, button_text, button_data)
    div(class: "input-group") do
      render(field_component)
      span(class: "input-group-btn") do
        button(
          type: "button",
          class: "btn btn-default",
          data: button_data
        ) { button_text }
      end
    end
  end

  # Get label text (from prefs, explicit label, or field name)
  def get_label_text(field_name, label, prefs)
    return :"prefs_#{field_name}".t if prefs
    return label if label.present?

    field_name.to_s.humanize
  end

  # Build form-group wrap class with inline and custom classes
  def form_group_wrap_class(base, inline, class_name)
    wrap_class = base

    # checkbox and radio do not need explicit `form-inline` class
    wrap_class += " form-inline" if inline && base == "form-group"
    wrap_class += " #{class_name}" if class_name.present?

    wrap_class
  end

  # Process optional/required shorthand (:optional or :required symbols)
  # Returns symbols to be rendered as components later
  def process_optional_required(between, append)
    positions = { between: between, append: append }
    keys = [:optional, :required]

    positions.each do |pos, value|
      next if value.blank?

      keys.each do |key|
        next unless value == key

        # Just return the symbol, will be rendered as component later
        positions[pos] = key
      end
    end

    [positions[:between], positions[:append]]
  end

  # Build help block info - returns hash with rendering info instead of HTML
  def add_help_block(field, between:, append:, help:, inline:)
    help_id = help_block_id(field)

    # Return rendering info instead of captured HTML
    between_info = {
      class: inline ? "mr-3" : "form-between",
      content: between,
      help_id: help_id
    }

    append_info = {
      content: append,
      help_text: help,
      help_id: help_id
    }

    [between_info, append_info]
  end

  # Generate help block ID
  def help_block_id(field)
    [
      key.to_s,
      field.key.to_s,
      "help"
    ].compact_blank.join("_")
  end
end
# rubocop:enable Metrics/ClassLength
