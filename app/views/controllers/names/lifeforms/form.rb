# frozen_string_literal: true

# Form for editing Name lifeform tags. Rendered by
# `Names::LifeformsController#edit`.
module Views::Controllers::Names::Lifeforms
  class Form < ::Components::ApplicationForm
    def initialize(model, name:, **)
      @name = name
      super(model, **)
    end

    def view_template
      p { :edit_lifeform_help.t }

      Table(Name.all_lifeforms,
            variant: :striped, identifier: "lifeform",
            show_headers: false) do |t|
        t.column(nil) do |word|
          checkbox_field(word.to_sym, label: :"lifeform_#{word}")
        end
        t.column(nil, class: "container-text") do |word|
          plain(:"lifeform_help_#{word}".t)
        end
      end

      submit(:SAVE.t, center: true)
    end

    private

    def form_action
      lifeform_of_name_path(@name.id, q: q_param)
    end
  end
end
