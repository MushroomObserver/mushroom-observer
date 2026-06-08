# frozen_string_literal: true

# Form for inheriting classification from a parent name. Rendered by
# `Names::Classification::InheritController#new`. Creates its own
# FormObject internally from the provided kwargs.
module Views::Controllers::Names::Classification::Inherit
  class Form < ::Components::ApplicationForm
    def initialize(name:, parent: nil, candidates: nil, message: nil, **)
      @name = name
      @candidates = candidates
      @message = message

      form_object = FormObject::InheritClassification.new(parent: parent)
      super(form_object, **)
    end

    def view_template
      render_candidates_alert if @candidates

      text_field(:parent, label: "#{:inherit_classification_parent_name.l}:",
                          data: { autofocus: true }, inline: true)

      submit(:SUBMIT.l, center: true)
    end

    private

    def render_candidates_alert
      render(Components::Alert.new(level: :warning)) do
        trusted_html(@message.tp)
        options = @candidates.map { |opt| [opt.id, opt.display_name.t] }
        radio_field(:candidates, *options)
      end
    end

    def form_action
      inherit_classification_of_name_path(@name.id)
    end
  end
end
