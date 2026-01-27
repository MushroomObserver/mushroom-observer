# frozen_string_literal: true

# Form for inheriting classification from a parent name
#
# @example
#   render(Components::NameInheritClassificationForm.new(
#     form_object,
#     name: @name,
#     context: { parent_text_name: @parent_text_name,
#                options: @options, message: @message }
#   ))
#
class Components::NameInheritClassificationForm < Components::ApplicationForm
  def initialize(model, name:, context: {}, **)
    @name = name
    @parent_text_name = context[:parent_text_name]
    @options = context[:options]
    @message = context[:message]
    super(model, **)
  end

  def view_template
    render_options_alert if @options

    text_field(:parent, label: "#{:inherit_classification_parent_name.t}:",
                        value: @parent_text_name,
                        data: { autofocus: true }, inline: true)

    submit(:SUBMIT.t, center: true)
  end

  private

  def render_options_alert
    render(Components::Alert.new(level: :warning)) do
      trusted_html(@message.tp)
      render_radio_options
    end
  end

  def render_radio_options
    @options.each do |opt|
      label do
        input(type: "radio",
              name: "inherit_classification[options]",
              id: "inherit_classification_options_#{opt.id}",
              value: opt.id)
        whitespace
        trusted_html(opt.display_name.t)
      end
    end
  end

  def form_action
    inherit_classification_of_name_path(@name.id)
  end
end
