# frozen_string_literal: true

# Displays feedback for name fields when the entered name is:
# - Not recognized
# - Deprecated (with valid synonyms)
# - Ambiguous (multiple matches)
# - Has a deprecated parent
#
# @param given_name [String] the name typed by user
# @param button_name [String] the button text (e.g., "Create", "Submit")
# @param names [Array<Name>, nil] Name objects matching the given_name
# @param valid_names [Array<Name>, nil] valid synonym Name objects
# @param suggest_corrections [Boolean] whether to suggest corrections
# @param parent_deprecated [Name, nil] deprecated parent Name
class Components::FormNameFeedback < Components::Base
  prop :given_name, String
  prop :button_name, String
  prop :names, _Nilable(_Array(Name)), default: nil
  prop :valid_names, _Nilable(_Array(Name)), default: nil
  prop :suggest_corrections, _Boolean, default: false
  prop :parent_deprecated, _Nilable(Name), default: nil

  def view_template
    if @valid_names
      render_warning_alert
    elsif @names&.empty?
      render_not_recognized_error
    elsif @names && @names.length > 1
      render_multiple_names_error
    end
  end

  private

  # ----- Warning alerts -----

  def render_warning_alert
    render(Components::Alert.new(level: :warning, id: "name_messages")) do
      div { warning_message }
      render_warning_help
      render_valid_name_choices if @valid_names&.any?
    end
  end

  def warning_message
    if @suggest_corrections || @names.blank?
      :form_naming_not_recognized.t(name: @given_name)
    elsif @parent_deprecated
      :form_naming_parent_deprecated.t(
        parent: @parent_deprecated.display_name,
        rank: :"rank_#{@parent_deprecated.rank.to_s.downcase}"
      )
    elsif @names.present?
      :form_naming_deprecated.t(name: @given_name)
    end
  end

  def render_warning_help
    return unless @valid_names&.any?

    help_text = if @suggest_corrections
                  :form_naming_correct_help.t(button: @button_name,
                                              name: @given_name)
                else
                  :form_naming_deprecated_help.t(button: @button_name,
                                                 name: @given_name)
                end
    div(class: "help-note mr-3") { help_text }
  end

  def render_valid_name_choices
    div do
      render_synonyms_header unless @suggest_corrections || @parent_deprecated
      render_name_radio_buttons(@valid_names)
    end
  end

  def render_synonyms_header
    div { "#{:form_naming_valid_synonyms.t}:" }
  end

  # ----- Error alerts -----

  def render_not_recognized_error
    render(Components::Alert.new(level: :danger, id: "name_messages")) do
      div { :form_naming_not_recognized.t(name: @given_name) }
      div(class: "help-note mr-3") do
        :form_naming_not_recognized_help.t(button: @button_name)
      end
    end
  end

  def render_multiple_names_error
    render(Components::Alert.new(level: :danger, id: "name_messages")) do
      div { [:form_naming_multiple_names.t(name: @given_name), ":"].safe_join }
      render_name_radio_buttons_with_counts(@names)
      div(class: "help-note mr-3") { :form_naming_multiple_names_help.t }
    end
  end

  # ----- Radio button helpers -----

  def render_name_radio_buttons(names)
    render(name_radio_field(names, wrap_class: "ml-4"))
  end

  def render_name_radio_buttons_with_counts(names)
    options = names.map do |n|
      count = n.observations.size
      [n.id, [n.display_name.t, " (#{count})"].safe_join]
    end
    render(name_radio_field(options, wrap_class: "ml-4 name-radio"))
  end

  def name_radio_field(options, wrap_class:)
    options = options.map { |n| [n.id, n.display_name.t] } if
      options.first.is_a?(Name)

    proxy = Components::ApplicationForm::FieldProxy.new(
      "chosen_name", :name_id
    )
    Components::ApplicationForm::RadioField.new(
      proxy, *options,
      wrapper_options: { wrap_class: wrap_class }
    )
  end
end
