# frozen_string_literal: true

# Form for propagating lifeform tags to child names
#
# @example
#   render(Components::NamePropagateLifeformForm.new(
#     FormObject::PropagateLifeform.new,
#     name: @name
#   ))
#
class Components::NamePropagateLifeformForm < Components::ApplicationForm
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

    table(class: "table table-lifeform table-striped") do
      lifeforms_on_name.each { |word| render_lifeform_row("add_#{word}", word) }
    end
  end

  def render_remove_section
    p do
      b { :REMOVE.l }
      plain(": ")
      plain(:propagate_lifeform_remove.l)
    end

    table(class: "table table-lifeform table-striped") do
      lifeforms_not_on_name.each do |word|
        render_lifeform_row("remove_#{word}", word)
      end
    end
  end

  def render_lifeform_row(field_name, word)
    tr do
      td { checkbox_field(field_name.to_sym, label: :"lifeform_#{word}".l) }
      td(class: "container-text") { :"lifeform_help_#{word}".t }
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
