# frozen_string_literal: true

# Form for inheriting classification from a parent name
#
# @example
#   render(Components::NameInheritClassificationForm.new(
#     FormObject::InheritClassification.new(parent: @parent_text_name),
#     name: @name,
#     context: { options: @options, message: @message }
#   ))
#
class Components::NameInheritClassificationForm < Components::ApplicationForm
  def initialize(model, name:, context: {}, **)
    @name = name
    @options = context[:options]
    @message = context[:message]
    super(model, **)
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
