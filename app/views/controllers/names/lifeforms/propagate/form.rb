# frozen_string_literal: true

# Form for propagating lifeform tags to child names. Rendered by
# `Names::Lifeforms::PropagateController#edit`.
module Views::Controllers::Names::Lifeforms::Propagate
  class Form < ::Components::ApplicationForm
    def initialize(model, name:, **)
      @name = name
      super(model, **)
    end

    def view_template
      render_add_section
      br
      render_remove_section
      submit(:APPLY.l, center: true)
    end

    private

    def render_add_section
      p do
        b { :ADD.l }
        plain(": ")
        plain(:propagate_lifeform_add.l)
      end

      render(Components::Table.new(lifeforms_on_name,
                                   variant: :striped,
                                   identifier: "lifeform",
                                   show_headers: false)) do |t|
        t.column(nil) do |word|
          checkbox_field(:"add_#{word}", label: :"lifeform_#{word}".l)
        end
        t.column(nil, class: "container-text") do |word|
          plain(:"lifeform_help_#{word}".t)
        end
      end
    end

    def render_remove_section
      p do
        b { :REMOVE.l }
        plain(": ")
        plain(:propagate_lifeform_remove.l)
      end

      render(Components::Table.new(lifeforms_not_on_name,
                                   variant: :striped,
                                   identifier: "lifeform",
                                   show_headers: false)) do |t|
        t.column(nil) do |word|
          checkbox_field(:"remove_#{word}", label: :"lifeform_#{word}".l)
        end
        t.column(nil, class: "container-text") do |word|
          plain(:"lifeform_help_#{word}".t)
        end
      end
    end

    def lifeforms_on_name
      Name.all_lifeforms.select { |word| @name.lifeform.include?(" #{word} ") }
    end

    def lifeforms_not_on_name
      Name.all_lifeforms.reject { |word| @name.lifeform.include?(" #{word} ") }
    end

    def form_action
      propagate_lifeform_of_name_path(@name.id, q: q_param)
    end
  end
end
