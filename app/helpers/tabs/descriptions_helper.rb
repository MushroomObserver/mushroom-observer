# frozen_string_literal: true

# html used in tabsets
module Tabs
  module DescriptionsHelper
    # Links for the tabset
    def show_description_tabs(description:)
      type = description.parent.type_tag
      admin = is_admin?(description)
      # assemble HTML for "tabset" for show_{type}_description
      [
        description_parent_tab(description, type),
        edit_description_tab(description),
        destroy_description_tab(description, admin),
        clone_description_tab(description),
        merge_description_tab(description, admin),
        adjust_description_permissions_tab(description, type, admin),
        make_description_default_tab(description),
        description_project_tab(description),
        publish_description_draft_tab(description, type, admin)
      ].reject(&:empty?)
    end

    # Components of the above AND similar links for helpers/descriptions_helper
    def description_parent_tab(description, type)
      [:show_object.t(type: type),
       add_query_param(description.parent.show_link_args),
       { class: "#{tab_id(__method__.to_s)}_#{description.id}" }]
    end

    def create_description_tab(object)
      [:show_name_create_description.t,
       { controller: "#{object.show_controller}/descriptions",
         action: :new, id: object.id, q: get_query_param },
       { class: "#{tab_id(__method__.to_s)}_#{object.id}" }]
    end

    def edit_description_tab(description)
      return unless writer?(description)

      [:show_description_edit.t,
       add_query_param(description.edit_link_args),
       { class: "#{tab_id(__method__.to_s)}_#{description.id}" }]
    end

    def destroy_description_tab(description, admin)
      return unless admin

      [:show_description_destroy.t, description, { button: :destroy }]
    end

    # icon("fa-regular", "clone", class: "fa-lg")
    def clone_description_tab(description)
      [:show_description_clone.t,
       { controller: description.show_controller,
         action: :new, id: description.parent_id,
         clone: description.id, q: get_query_param },
       { help: :show_description_clone_help.l,
         class: "#{tab_id(__method__.to_s)}_#{description.id}",
         data: { toggle: "tooltip", placement: "top",
                 title: :show_description_clone.t } }]
    end

    # icon("fa-regular", "code-merge", class: "fa-lg")
    def merge_description_tab(description, admin)
      return unless admin

      [:show_description_merge.t,
       { controller: "#{description.show_controller}/merges",
         action: :new, id: description.id, q: get_query_param },
       { help: :show_description_merge_help.l,
         class: "#{tab_id(__method__.to_s)}_#{description.id}",
         data: { toggle: "tooltip", placement: "top",
                 title: :show_description_merge.t } }]
    end

    # icon("fa-regular", "file-export", class: "fa-lg")
    def move_description_tab(description, admin)
      return unless admin

      parent_type = description.parent.type_tag.to_s
      [:show_description_move.t,
       { controller: "#{description.show_controller}/moves",
         action: :new, id: description.id, q: get_query_param },
       { help: :show_description_move_help.l(parent: parent_type),
         class: "#{tab_id(__method__.to_s)}_#{description.id}",
         data: { toggle: "tooltip", placement: "top",
                 title: :show_description_move.t } }]
    end

    # icon("fa-regular", "arrows-down-to-people", class: "fa-lg")
    def adjust_description_permissions_tab(description, type, admin)
      return unless admin && type == :name

      [:show_description_adjust_permissions.t,
       { controller: "#{description.show_controller}/permissions",
         action: :edit, id: description.id, q: get_query_param },
       { help: :show_description_adjust_permissions_help.l,
         class: "#{tab_id(__method__.to_s)}_#{description.id}",
         data: { toggle: "tooltip", placement: "top",
                 title: :show_description_adjust_permissions.t } }]
    end

    # icon("fa-regular", "star", class: "fa-lg")
    def make_description_default_tab(description)
      return unless description.public && User.current &&
                    (description.parent.description_id != description.id)

      [:show_description_make_default.t,
       { controller: "#{description.show_controller}/defaults",
         action: :update, id: description.id,
         q: get_query_param },
       { button: :put, help: :show_description_make_default_help.l,
         class: "#{tab_id(__method__.to_s)}_#{description.id}",
         data: { toggle: "tooltip", placement: "top",
                 title: :show_description_make_default.t } }]
    end

    # icon("fa-regular", "people-arrows", class: "fa-lg")
    def description_project_tab(description)
      return unless (description.source_type == :project) &&
                    (project = description.source_object)

      [:show_object.t(type: :project), add_query_param(project.show_link_args),
       { class: __method__.to_s,
         data: { toggle: "tooltip", placement: "top",
                 title: :show_object.t(type: :project) } }]
    end

    # icon("fa-regular", "check-to-slot", class: "fa-lg")
    def publish_description_draft_tab(description, type, admin)
      return unless admin && (type == :name) &&
                    (description.source_type != :public)

      [:show_description_publish.t,
       { controller: "#{description.show_controller}/publish",
         action: :update, id: description.id,
         q: get_query_param },
       { button: :put, help: :show_description_publish_help.l,
         class: tab_id(__method__.to_s),
         data: { toggle: "tooltip", placement: "top",
                 title: :show_description_publish.t } }]
    end

    def new_description_for_project_tab(object, project)
      [project.title,
       { controller: "#{object.show_controller}/descriptions",
         action: :new, id: object.id,
         project: project.id, source: "project" },
       { class: tab_id(__method__.to_s) }]
    end

    def descriptions_index_sorts
      [
        ["name",        :sort_by_name.t],
        ["created_at",  :sort_by_created_at.t],
        ["updated_at",  :sort_by_updated_at.t],
        ["num_views",   :sort_by_num_views.t]
      ].freeze
    end
  end
end
