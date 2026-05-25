# frozen_string_literal: true

# Form for editing Name lifeform tags. Rendered by
# `Names::LifeformsController#edit`.
module Views::Controllers::Names::Lifeforms
  class Form < ::Components::ApplicationForm
    def initialize(model, name:, **)
      @name = name
      super(model, id: "name_lifeform_form", **)
    end

    def view_template
      p { :edit_lifeform_help.t }

      table(class: "table table-lifeform table-striped") do
        Name.all_lifeforms.each { |word| render_lifeform_row(word) }
      end

      submit(:SAVE.t, center: true)
    end

    private

    def render_lifeform_row(word)
      tr do
        td { checkbox_field(word.to_sym, label: :"lifeform_#{word}".l) }
        td(class: "container-text") { :"lifeform_help_#{word}".t }
      end
    end

    def form_action
      lifeform_of_name_path(@name.id, q: q_param)
    end
  end
end
