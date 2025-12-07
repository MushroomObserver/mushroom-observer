# frozen_string_literal: true

# Form for proposing or editing a naming on an observation.
# Extends ApplicationForm (Superform) and uses the field builder methods.
#
# @param naming [Naming] the naming model
# @param observation [Observation] the parent observation
# @param vote [Vote] the vote object (defaults to new Vote)
# @param given_name [String] the name typed by user
# @param reasons [Hash] the naming reasons
# @param feedback [Hash] name feedback options:
#   - :names - matched Name objects
#   - :valid_names - valid synonym Name objects
#   - :suggest_corrections - whether to suggest corrections
#   - :parent_deprecated - deprecated parent Name
# @param show_reasons [Boolean] whether to show reason fields
# @param context [String] form context ("blank", "lightbox", etc.)
# @param local [Boolean] if true, non-turbo form
class Components::NamingForm < Components::ApplicationForm
  def initialize(naming, **kwargs)
    extract_kwargs(naming, kwargs)
    super(naming, id: form_id_value, local: @local, **kwargs)
  end

  def view_template
    if @given_name.present?
      render(partial("shared/form_name_feedback", **feedback_locals))
    end
    render_naming_namespace
    input(type: "hidden", name: "context", value: @context)
    submit(button_name, center: true)
  end

  # Override form_action to derive URL from observation
  def form_action
    if @create
      observation_namings_path(
        observation_id: @observation.id,
        approved_name: @given_name
      )
    else
      observation_naming_path(
        observation_id: @observation.id,
        id: @naming_id,
        approved_name: @given_name
      )
    end
  end

  private

  def extract_kwargs(naming, kwargs)
    extract_form_data(kwargs)
    extract_display_options(naming, kwargs)
  end

  def extract_form_data(kwargs)
    @observation = kwargs.delete(:observation)
    @vote = kwargs.delete(:vote) || Vote.new
    @given_name = kwargs.delete(:given_name) || ""
    @feedback = kwargs.delete(:feedback) || {}
  end

  def extract_display_options(naming, kwargs)
    @reasons = kwargs.delete(:reasons) || naming.init_reasons
    @show_reasons = kwargs.delete(:show_reasons) != false
    @context = kwargs.delete(:context) || "blank"
    @local = kwargs.delete(:local) != false
    @create = naming.new_record?
    @naming_id = naming.id
  end

  def form_id_value
    if @create
      "obs_#{@observation.id}_naming_form"
    else
      "obs_#{@observation.id}_naming_#{@naming_id}_form"
    end
  end

  def button_name
    @create ? :CREATE.l : :SAVE_EDITS.l
  end

  def feedback_locals
    {
      button_name: button_name,
      given_name: @given_name,
      names: @feedback[:names],
      valid_names: @feedback[:valid_names],
      suggest_corrections: @feedback[:suggest_corrections],
      parent_deprecated: @feedback[:parent_deprecated]
    }
  end

  def render_naming_namespace
    # Don't wrap in namespace(:naming) - the form is already for a Naming model
    render_name_autocompleter(self)
  end

  def render_name_autocompleter(naming)
    name_field = naming.field(:name).autocompleter(
      type: :name,
      wrapper_options: {
        label: "#{:WHAT.t}:",
        help: :form_naming_name_help.t
      },
      value: @given_name,
      autofocus: focus_on_name?
    )

    render(name_field) do
      render_vote_reasons_collapse(naming)
    end
  end

  def render_vote_reasons_collapse(naming)
    div(data: { autocompleter_target: "collapseFields" },
        class: collapse_class) do
      render_vote_field(naming)
      render_reasons_field if @show_reasons
    end
  end

  def collapse_class
    @context == "blank" ? "collapse" : nil
  end

  def render_vote_field(naming)
    naming.namespace(:vote) do |vote|
      menu = @create ? [["", ""]] + confidence_menu : confidence_menu
      render(vote.field(:value).select(
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
    render(Components::NamingReasonsFields.new(
             reasons: @reasons,
             form_namespace: self
           ))
  end

  def confidence_menu
    # Superform expects [value, label] but Rails returns [label, value]
    menu = if @vote&.value&.nonzero?
             Vote.confidence_menu
           else
             Vote.opinion_menu
           end
    menu.map { |label, value| [value, label] }
  end

  def focus_on_name?
    !@create || @given_name.empty?
  end

  def focus_on_vote?
    @create && @given_name.present?
  end
end
