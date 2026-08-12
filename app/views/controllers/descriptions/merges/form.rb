# frozen_string_literal: true

module Views::Controllers::Descriptions::Merges
  # Form for merging a description into another description of the same
  # parent. Used for both NameDescription and LocationDescription, so it
  # lives in the shared `descriptions/` namespace rather than under
  # either parent controller.
  class Form < ::Components::ApplicationForm
    prop :description, ::Description
    prop :user, ::User

    def initialize(description, user:)
      # Computed from the local `description`/`user` params, not
      # `@description`/`merges` (which read the `@description` prop)
      # -- prop assignment hasn't happened yet at this point in
      # construction.
      other_descriptions = description.parent.descriptions - [description]
      form_object = FormObject::DescriptionMoveOrMerge.new
      form_object.target = other_descriptions.first.id if
        other_descriptions.length == 1
      form_object.delete = description.is_admin?(user)
      # Keep the explicit DOM id — tests, integration specs, and the
      # auto-derived `description_merge_form` would all rename to a
      # less-recognizable string.
      super(form_object, description: description, user: user,
                         id: "merge_descriptions_form")
    end

    def view_template
      h4 { "#{:merge_descriptions_merge_header.t}:" }
      Help(element: :p,
           content: :merge_descriptions_merge_help.t)

      div(class: "form-group") { render_merge_options }

      render_delete_checkbox if merges.any?
      render_submit if merges.any?
    end

    private

    def render_merge_options
      if merges.any?
        options = merges.map do |desc|
          [desc.id, description_title(@user, desc)]
        end
        radio_field(:target, *options)
      else
        p { :merge_descriptions_no_others.t }
      end
    end

    def render_delete_checkbox
      checkbox_field(:delete, label: :merge_descriptions_delete_after)
    end

    def render_submit
      submit(:submit.ti, center: true)
    end

    def merges
      @merges ||= @description.parent.descriptions - [@description]
    end

    def description_title(user, desc)
      result = desc.partial_format_name

      # Indicate rough permissions.
      permit = if desc.parent.description_id == desc.id
                 :default.l
               elsif desc.public
                 :public.l
               elsif user_reader?(user, desc)
                 :restricted.l
               else
                 :private.l
               end
      result += " (#{permit})" unless /(^| )#{permit}( |$)/i.match?(result)

      result
    end

    def user_reader?(user, desc)
      desc.is_reader?(user) || in_admin_mode?
    end

    def name_description?
      @description.is_a?(NameDescription)
    end

    def form_action
      if name_description?
        url_for(controller: "/names/descriptions/merges", action: :create,
                id: @description.id, only_path: true)
      else
        url_for(controller: "/locations/descriptions/merges", action: :create,
                id: @description.id, only_path: true)
      end
    end

    def form_method
      :post
    end
  end
end
