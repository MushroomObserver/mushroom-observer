# frozen_string_literal: true

# html used in tabsets
module Tabs
  module DescriptionsHelper
    # The whole tabset, made of composed links.
    def show_description_tabset(description:, pager: false)
      type = description.parent.type_tag
      admin = is_admin?(description)
      # assemble HTML for "tabset" for show_{type}_description
      tabs = [
        show_parent_link(description, type),
        edit_description_link(description),
        destroy_description_link(description, admin),
        clone_description_link(description),
        merge_description_link(description, admin),
        adjust_permissions_link(description, type, admin),
        make_default_link(description),
        project_link(description),
        publish_draft_link(description, type, admin)
      ].flatten.reject(&:empty?)
      tabset = { right: draw_tab_set(tabs) }
      tabset = tabset.merge(pager_for: description) if pager
      tabset
    end

    def show_parent_link(description, type)
      link_with_query(:show_object.t(type: type),
                      description.parent.show_link_args)
    end

    def create_description_link(object)
      link_to(
        :show_name_create_description.t,
        { controller: "#{object.show_controller}/descriptions",
          action: :new, id: object.id, q: get_query_param },
        class: "create_description_link_#{object.id}"
      )
    end

    def edit_description_link(description)
      return unless writer?(description)

      link_with_query(
        :show_description_edit.t, description.edit_link_args
      )
    end

    def destroy_description_link(description, admin)
      return unless admin

      destroy_button(name: :show_description_destroy.t,
                     target: description, q: get_query_param)
    end

    def clone_description_link(description)
      link_with_query(
        :show_description_clone.t,
        { controller: description.show_controller,
          action: :new, id: description.parent_id,
          clone: description.id },
        help: :show_description_clone_help.l
      )
    end

    def merge_description_link(description, admin)
      return unless admin

      link_with_query(
        :show_description_merge.t,
        { controller: "#{description.show_controller}/merges",
          action: :new, id: description.id },
        help: :show_description_merge_help.l
      )
    end

    def move_description_link(description, admin)
      return unless admin

      parent_type = description.parent.type_tag.to_s
      link_with_query(
        :show_description_move.t,
        { controller: "#{description.show_controller}/moves",
          action: :new, id: description.id },
        help: :show_description_move_help.l(parent: parent_type)
      )
    end

    def adjust_permissions_link(description, type, admin)
      return unless admin && type == :name

      link_with_query(
        :show_description_adjust_permissions.t,
        { controller: "#{description.show_controller}/permissions",
          action: :edit, id: description.id },
        help: :show_description_adjust_permissions_help.l
      )
    end

    def make_default_link(description)
      return unless description.public && User.current &&
                    (description.parent.description_id != description.id)

      put_button(
        name: :show_description_make_default.t,
        path: { controller: "#{description.show_controller}/defaults",
                action: :update, id: description.id,
                q: get_query_param },
        help: :show_description_make_default_help.l
      )
    end

    def project_link(description)
      return unless (description.source_type == :project) &&
                    (project = description.source_object)

      link_with_query(
        :show_object.t(type: :project), project.show_link_args
      )
    end

    def publish_draft_link(description, type, admin)
      return unless admin && (type == :name) &&
                    (description.source_type != :public)

      put_button(
        name: :show_description_publish.t,
        path: { controller: "#{description.show_controller}/publish",
                action: :update, id: description.id,
                q: get_query_param },
        help: :show_description_publish_help.l
      )
    end
  end
end
