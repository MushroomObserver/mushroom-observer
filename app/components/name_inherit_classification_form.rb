# frozen_string_literal: true

# Form for inheriting classification from a parent name.
# Creates its own FormObject internally from the provided kwargs.
#
# @example
#   render(Components::NameInheritClassificationForm.new(
#     name: @name,
#     parent: @parent_text_name,
#     options: @options,
#     message: @message
#   ))
#
class Components::NameInheritClassificationForm < Components::ApplicationForm
  def initialize(name:, parent: nil, options: nil, message: nil, **)
    @name = name
    @options = options
    @message = message

    form_object = FormObject::InheritClassification.new(parent: parent)
    super(form_object, **)
  end

  def view_template
    render_options_alert if @options

    text_field(:parent, label: "#{:inherit_classification_parent_name.l}:",
                        data: { autofocus: true }, inline: true)

    submit(:SUBMIT.l, center: true)
  end

  private

  def render_options_alert
    render(Components::Alert.new(level: :warning)) do
      trusted_html(@message.tp)
      options = @options.map { |opt| [opt.id, opt.display_name.t] }
      radio_field(:options, *options)
    end
  end

  def form_action
    inherit_classification_of_name_path(@name.id)
  end
end
