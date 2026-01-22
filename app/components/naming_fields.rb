# frozen_string_literal: true

# Renders naming fields (name autocompleter, vote, reasons) for embedding
# in Superform-based forms. For ERB forms, use the _fields.erb partial.
#
# @param form [Components::ApplicationForm] the parent form
# @param vote [Vote] the vote object
# @param given_name [String] the name typed by user
# @param reasons [Hash] the naming reasons from Naming#init_reasons
# @param show_reasons [Boolean] whether to show reason fields
# @param context [String] form context ("blank", "lightbox", etc.)
# @param create [Boolean] whether this is a new naming
# @param name_help [String] help text for the name field
# @param unfocused [Boolean] if true, don't autofocus any field
class Components::NamingFields < Components::Base
  prop :form, _Any
  prop :vote, _Nilable(Vote), default: -> { Vote.new }
  prop :given_name, String, default: ""
  prop :reasons, _Nilable(Hash), default: nil
  prop :show_reasons, _Boolean, default: true
  prop :context, _Nilable(String), default: nil
  prop :create, _Boolean, default: true
  prop :name_help, String, default: -> { :form_naming_name_help.t }
  prop :unfocused, _Boolean, default: false
  prop :add_namespace, _Boolean, default: true

  def view_template
    if @add_namespace
      @form.namespace(:naming) do |naming_ns|
        render_name_autocompleter(naming_ns)
      end
    else
      render_name_autocompleter(@form)
    end
    # Hidden field tells controller where form was submitted from
    input(type: "hidden", name: "context", value: @context) if @context
  end

  private

  def render_name_autocompleter(naming_ns)
    @naming_ns = naming_ns
    name_field = naming_ns.field(:name).autocompleter(
      type: :name,
      wrapper_options: { label: "#{:WHAT.t}:" },
      value: @given_name,
      autofocus: focus_on_name?
    )

    name_field.with_help { @name_help }
    name_field.with_append { render_vote_reasons_collapse }
    render(name_field)
  end

  def render_vote_reasons_collapse
    div(data: { autocompleter__name_target: "collapseFields" },
        class: collapse_class) do
      render_vote_field
      render_reasons_field
    end
  end

  def render_vote_field
    @naming_ns.namespace(:vote) do |vote_ns|
      menu = @create ? [["", ""]] + confidence_menu : confidence_menu
      render(vote_ns.field(:value).select(
               menu,
               wrapper_options: {
                 label: "#{:form_naming_confidence.t}:",
                 wrap_class: "mt-3"
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
             naming_ns: @naming_ns
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
