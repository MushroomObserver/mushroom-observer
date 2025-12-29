# frozen_string_literal: true

# Renders naming fields (name autocompleter, vote, reasons) for embedding
# in Superform-based forms. For ERB forms, use the _fields.erb partial.
#
# @param form_namespace [Superform::Namespace] the parent form namespace
# @param vote [Vote] the vote object
# @param given_name [String] the name typed by user
# @param reasons [Hash] the naming reasons from Naming#init_reasons
# @param show_reasons [Boolean] whether to show reason fields
# @param context [String] form context ("blank", "lightbox", etc.)
# @param create [Boolean] whether this is a new naming
# @param name_help [String] help text for the name field
# @param unfocused [Boolean] if true, don't autofocus any field
class Components::NamingFields < Components::Base
  prop :form_namespace, _Any
  prop :vote, _Nilable(Vote), default: -> { Vote.new }
  prop :given_name, String, default: ""
  prop :reasons, _Nilable(Hash), default: nil
  prop :show_reasons, _Boolean, default: true
  prop :context, _Nilable(String), default: nil
  prop :create, _Boolean, default: true
  prop :name_help, String, default: -> { :form_naming_name_help.t }
  prop :unfocused, _Boolean, default: false

  def view_template
    render_name_autocompleter
  end

  private

  def render_name_autocompleter
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
      render_vote_reasons_collapse
    end
  end

  def render_vote_reasons_collapse
    div(data: { autocompleter__name_target: "collapseFields" },
        class: collapse_class) do
      render_vote_field
      render_reasons_field if @show_reasons
    end
  end

  def render_vote_field
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

  def render_reasons_field
    return unless @reasons

    render(Components::NamingReasonsFields.new(
             reasons: @reasons,
             form_namespace: @form_namespace
           ))
  end

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
