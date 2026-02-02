# frozen_string_literal: true

# Form for moving a description to a synonym of its parent.
# Used for both NameDescription and LocationDescription.
class Components::Descriptions::MoveForm < Components::ApplicationForm
  def initialize(description, user:)
    @description = description
    @user = user
    form_object = FormObject::DescriptionAction.new
    form_object.target = default_target_id if default_checked?
    form_object.delete = description.is_admin?(user)
    super(form_object, id: "move_descriptions_form")
  end

  def view_template
    h4 { "#{:merge_descriptions_move_header.t}:" }
    p(class: "help-note") { :merge_descriptions_move_help.t }

    return unless moves.any?

    div(class: "form-group") { render_move_options }
    render_delete_checkbox
    render_submit
  end

  private

  def render_move_options
    options = sorted_moves.map { |name| [name.id, name.display_name.t] }
    radio_field(:target, *options)
  end

  def default_target_id
    sorted_moves.first&.id
  end

  def render_delete_checkbox
    checkbox_field(:delete, label: :merge_descriptions_delete_after.t)
  end

  def render_submit
    submit(:SUBMIT.l, center: true)
  end

  def merges
    @merges ||= @description.parent.descriptions - [@description]
  end

  def moves
    @moves ||=
      begin
        result = @description.parent.synonyms - [@description.parent]
        result.reject!(&:is_misspelling?)
        result
      end
  end

  def sorted_moves
    moves.sort_by { |n| [(n.deprecated ? 1 : 0), n.sort_name, n.id] }
  end

  def default_checked?
    merges.empty? && moves.length == 1
  end

  def name_description?
    @description.is_a?(NameDescription)
  end

  def form_action
    if name_description?
      url_for(controller: "/names/descriptions/moves", action: :create,
              id: @description.id, only_path: true)
    else
      url_for(controller: "/locations/descriptions/moves", action: :create,
              id: @description.id, only_path: true)
    end
  end

  def form_method
    :post
  end
end
