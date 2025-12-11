# frozen_string_literal: true

# Renders naming fields (name autocompleter, vote, reasons) for embedding
# in forms. Can be used standalone or within a larger form like observation.
#
# Two usage modes:
# 1. Superform mode: pass form_namespace (a Superform namespace)
# 2. Rails mode: pass no form_namespace, uses fields_for(:naming) internally
#
# @param form_namespace [Superform::Namespace, nil] the parent form namespace
# @param vote [Vote] the vote object
# @param given_name [String] the name typed by user
# @param reasons [Hash] the naming reasons from Naming#init_reasons
# @param show_reasons [Boolean] whether to show reason fields
# @param context [String] form context ("blank", "lightbox", etc.)
# @param create [Boolean] whether this is a new naming
# @param name_help [String] help text for the name field
# @param unfocused [Boolean] if true, don't autofocus any field
class Components::NamingFields < Components::Base
  include Phlex::Rails::Helpers::FieldsFor

  register_output_helper :autocompleter_field
  register_output_helper :select_with_label
  register_output_helper :naming_form_reasons_fields

  prop :form_namespace, _Nilable(_Any), default: nil
  prop :vote, _Nilable(Vote), default: -> { Vote.new }
  prop :given_name, String, default: ""
  prop :reasons, _Nilable(Hash), default: nil
  prop :show_reasons, _Boolean, default: true
  prop :context, _Nilable(String), default: nil
  prop :create, _Boolean, default: true
  prop :name_help, String, default: -> { :form_naming_name_help.t }
  prop :unfocused, _Boolean, default: false

  def view_template
    if @form_namespace
      render_superform_fields
    else
      render_rails_fields
    end
  end

  private

  # ----- Superform mode -----

  def render_superform_fields
    render_name_autocompleter_superform
  end

  def render_name_autocompleter_superform
    name_field = @form_namespace.field(:name).autocompleter(
      type: :name,
      wrapper_options: {
        label: "#{:WHAT.t}:",
        help: @name_help
      },
      value: @given_name,
      autofocus: focus_on_name?
    )

    render(name_field) do
      render_vote_reasons_collapse_superform
    end
  end

  def render_vote_reasons_collapse_superform
    div(data: { autocompleter_target: "collapseFields" },
        class: collapse_class) do
      render_vote_field_superform
      render_reasons_field_superform if @show_reasons
    end
  end

  def render_vote_field_superform
    @form_namespace.namespace(:vote) do |vote_ns|
      menu = @create ? [["", ""]] + confidence_menu : confidence_menu
      render(vote_ns.field(:value).select(
               menu,
               wrapper_options: {
                 label: "#{:form_naming_confidence.t}:"
               },
               selected: @vote&.value,
               autofocus: focus_on_vote?
             ))
    end
  end

  def render_reasons_field_superform
    return unless @reasons

    render(Components::NamingReasonsFields.new(
             reasons: @reasons,
             form_namespace: @form_namespace
           ))
  end

  # ----- Rails mode (using fields_for) -----

  def render_rails_fields
    fields_for(:naming) do |f_n|
      vote_reasons_html = capture_vote_reasons(f_n)
      autocompleter_field(
        form: f_n, field: :name, type: :name,
        label: "#{:WHAT.t}:",
        value: @given_name, autofocus: focus_on_name?, help: @name_help,
        append: vote_reasons_html
      )
    end
  end

  def capture_vote_reasons(f_n)
    view_context.tag.div(
      data: { autocompleter_target: "collapseFields" },
      class: collapse_class
    ) do
      parts = []
      parts << render_vote_field_rails(f_n)
      parts << render_reasons_field_rails(f_n) if @show_reasons && @reasons
      view_context.safe_join(parts.compact)
    end
  end

  def render_vote_field_rails(f_n)
    f_n.fields_for(:vote) do |f_v|
      select_with_label(
        form: f_v, field: :value,
        options: raw_menu,
        selected: @vote&.value,
        include_blank: @create,
        label: "#{:form_naming_confidence.t}:",
        autofocus: focus_on_vote?
      )
    end
  end

  def render_reasons_field_rails(f_n)
    f_n.fields_for(:reasons) do |f_r|
      naming_form_reasons_fields(f_r, @reasons)
    end
  end

  # ----- Shared helpers -----

  def collapse_class
    @context == "blank" ? "collapse" : nil
  end

  def confidence_menu
    # Superform expects [value, label] but Rails returns [label, value]
    raw_menu.map { |label, value| [value, label] }
  end

  def raw_menu
    if @vote&.value&.nonzero?
      Vote.confidence_menu
    else
      Vote.opinion_menu
    end
  end

  def focus_on_name?
    return false if @unfocused

    !@create || @given_name.empty?
  end

  def focus_on_vote?
    return false if @unfocused

    @create && @given_name.present?
  end
end
