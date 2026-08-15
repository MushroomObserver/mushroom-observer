# frozen_string_literal: true

module Views::Controllers::Descriptions::Moves
  # Form for moving a description to a synonym of its parent. Only
  # meaningful for NameDescription since Location has no synonyms.
  # For LocationDescription, moves will be empty and only the header
  # shows. Shared between names/descriptions/moves and
  # locations/descriptions/moves.
  class Form < ::Components::ApplicationForm
    prop :description, ::Description
    prop :user, ::User

    def initialize(description, user:, **)
      # `self.class.sorted_moves_for` (not the instance `sorted_moves`,
      # which reads the `@description` prop) -- prop assignment hasn't
      # happened yet at this point in construction.
      sorted = self.class.sorted_moves_for(description)
      form_object = FormObject::DescriptionMoveOrMerge.new
      form_object.target = sorted.first.id if sorted.length == 1
      form_object.delete = description.is_admin?(user)
      # Keep the explicit DOM id — tests rely on it.
      super(form_object, description: description, user: user,
                         id: "move_descriptions_form", **)
    end

    # Location doesn't have synonyms, only Name does. Class methods
    # (not instance methods reading `@description`) so they're usable
    # from `initialize`, before prop assignment, as well as after.
    def self.moves_for(description)
      return [] unless description.parent.respond_to?(:synonyms)

      description.parent.synonyms.reject do |n|
        n == description.parent || n.is_misspelling?
      end
    end

    def self.sorted_moves_for(description)
      moves_for(description).sort_by do |n|
        [(n.deprecated ? 1 : 0), n.sort_name, n.id]
      end
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
    # (`moves_for` returns [] when the parent doesn't respond to
    # `synonyms`, which is only Name) - always Name instances.
    def render_move_options
      options = sorted_moves.map do |name|
        [name.id, name.display_name(@user).t]
      end
      radio_field(:target, *options)
    end

    def render_delete_checkbox
      checkbox_field(:delete, label: :merge_descriptions_delete_after)
    end

    def render_submit
      submit(:submit.ti, center: true)
    end

    def moves
      @moves ||= self.class.moves_for(@description)
    end

    def sorted_moves
      self.class.sorted_moves_for(@description)
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
