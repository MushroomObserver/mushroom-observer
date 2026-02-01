# frozen_string_literal: true

# Form for moving a description to a synonym of its parent.
# Used for both NameDescription and LocationDescription.
class Components::Descriptions::MoveForm < Components::Base
  include Phlex::Rails::Helpers::FormWith

  register_output_helper :radio_with_label, mark_safe: true
  register_value_helper :url_for

  def initialize(description, user:)
    super()
    @description = description
    @user = user
  end

  def view_template
    form_with(url: form_action, id: "move_descriptions_form") do |f|
      @form = f
      h4 { "#{:merge_descriptions_move_header.t}:" }
      p(class: "help-note") { :merge_descriptions_move_help.t }

      render_move_options if moves.any?
      render_delete_checkbox if moves.any?
      render_submit if moves.any?
    end
  end

  private

  def render_move_options
    div(class: "form-group") do
      sorted_moves.each do |name|
        radio_with_label(form: @form, field: :target, value: name.id,
                         label: name.display_name.t,
                         checked: default_checked?)
      end
    end
  end

  def render_delete_checkbox
    div(class: "form-check") do
      input(type: "checkbox", name: "delete", value: "1",
            id: "delete", class: "form-check-input",
            checked: @description.is_admin?(@user))
      label(for: "delete", class: "form-check-label") do
        :merge_descriptions_delete_after.t
      end
    end
  end

  def render_submit
    div(class: "text-center my-3") do
      input(type: "submit", value: :SUBMIT.l, class: "btn btn-default",
            data: { turbo_submits_with: :SUBMITTING.l })
    end
  end

  def merges
    @merges ||= @description.parent.descriptions - [@description]
  end

  def moves
    @moves ||= begin
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
end
