# frozen_string_literal: true

module Views::Controllers::Descriptions::Moves
  # Form for moving a description to a synonym of its parent. Only
  # meaningful for NameDescription since Location has no synonyms.
  # For LocationDescription, moves will be empty and only the header
  # shows. Shared between names/descriptions/moves and
  # locations/descriptions/moves.
  class Form < ::Components::ApplicationForm
    def initialize(description, user:)
      @description = description
      @user = user
      form_object = FormObject::DescriptionMoveOrMerge.new
      form_object.target = default_target_id if default_checked?
      form_object.delete = description.is_admin?(user)
      # Keep the explicit DOM id — tests rely on it.
      super(form_object, id: "move_descriptions_form")
    end

    def view_template
      h4 { "#{:merge_descriptions_move_header.t}:" }
      Help(element: :p,
           content: :merge_descriptions_move_help.t)

      return unless moves.any?

      div(class: "form-group") { render_move_options }
      render_delete_checkbox
      render_submit
    end

    private

    # `sorted_moves` is only ever populated for NameDescription moves
    # (`compute_moves` returns [] when the parent doesn't respond to
    # `synonyms`, which is only Name) - always Name instances.
    def render_move_options
      options = sorted_moves.map do |name|
        [name.id, name.display_name(@user).t]
      end
      radio_field(:target, *options)
    end

    def default_target_id
      # default_checked? guarantees moves.length == 1, so .first is safe.
      sorted_moves.first.id
    end

    def render_delete_checkbox
      checkbox_field(:delete, label: :merge_descriptions_delete_after.t)
    end

    def render_submit
      submit(:SUBMIT.l, center: true)
    end

    def moves
      @moves ||= compute_moves
    end

    def compute_moves
      # Location doesn't have synonyms, only Name does
      return [] unless @description.parent.respond_to?(:synonyms)

      result = @description.parent.synonyms - [@description.parent]
      result.reject!(&:is_misspelling?)
      result
    end

    def sorted_moves
      moves.sort_by { |n| [(n.deprecated ? 1 : 0), n.sort_name, n.id] }
    end

    def default_checked?
      moves.length == 1
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
end
