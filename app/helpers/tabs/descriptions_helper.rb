# frozen_string_literal: true

# html used in tabsets
module Tabs
  module DescriptionsHelper
    # Links for the tabset
    def show_description_tabs(description:)
      # type = description.parent.type_tag
      # admin = is_admin?(description)
      # assemble HTML for "tabset" for show_{type}_description
      # [
      #   description_parent_tab(description, type)
      #   edit_description_tab(description, type),
      #   destroy_description_tab(description, admin),
      #   clone_description_tab(description, type),
      #   merge_description_tab(description, type, admin),
      #   adjust_description_permissions_tab(description, type, admin),
      #   make_description_default_tab(description, type),
      #   description_project_tab(description),
      #   publish_description_draft_tab(description, type, admin)
      # ].reject(&:empty?)
    end

    def description_change_links(desc)
      type = desc.parent.type_tag
      admin = is_admin?(desc)
      [
        writer?(desc) ? edit_button(target: desc, icon: :edit) : nil,
        admin ? destroy_button(target: desc, icon: :delete) : nil,
        icon_link_to(*clone_description_tab(desc, type)),
        icon_link_to(*merge_description_tab(desc, type, admin)),
        icon_link_to(*adjust_description_permissions_tab(desc, type, admin)),
        icon_link_to(*make_description_default_tab(desc, type)),
        icon_link_to(*description_project_tab(desc)),
        icon_link_to(*publish_description_draft_tab(desc, type, admin))
      ].compact_blank.safe_join(" | ")
    end

    # Dead code?
    # # Components of the above AND similar links for helpers/descriptions_helper
    # def description_parent_tab(description, type)
    #   InternalLink::Model.new(
    #     :show_object.t(type: type), description,
    #     add_query_param(description.parent.show_link_args)
    #   ).tab
    # end

    def create_description_tab(object, type)
      InternalLink::Model.new(
        :show_name_create_description.t, "#{type.capitalize}Description",
        add_query_param(send(:"new_#{type}_description_path",
                             { "#{type}_id": object.id })),
        html_options: { icon: :add }
      ).tab
    end

    def edit_description_tab(description, type)
      return unless writer?(description)

      InternalLink::Model.new(
        :show_description_edit.t, description,
        add_query_param(send(:"edit_#{type}_description_path", description.id)),
        html_options: { icon: :edit }
      ).tab
    end

    # Dead code?
    # def destroy_description_tab(description, admin)
    #   return unless admin

    #   InternalLink::Model.new(
    #     :show_description_destroy.t, description, description,
    #     html_options: { button: :destroy }
    #   ).tab
    # end

    def clone_description_tab(description, type)
      InternalLink::Model.new(
        :show_description_clone.t, description,
        add_query_param(
          send(:"new_#{type}_description_path",
               { clone: description.id, "#{type}_id": description.parent_id })
        ),
        html_options: { help: :show_description_clone_help.l, icon: :clone }
      ).tab
    end

    def merge_description_tab(description, type, admin)
      return unless admin

      InternalLink::Model.new(
        :show_description_merge.t, description,
        add_query_param(
          send(:"new_merge_#{type}_description_path", description.id)
        ),
        html_options: { help: :show_description_merge_help.l, icon: :merge }
      ).tab
    end

    # Dead code?
    # def move_description_tab(description, type, admin)
    #   return unless admin

    #   parent_type = description.parent.type_tag.to_s
    #   InternalLink::Model.new(
    #     :show_description_move.t, description,
    #     add_query_param(
    #       send(:"new_move_#{type}_description_path", description.id)
    #     ),
    #     html_options: {
    #       help: :show_description_move_help.l(parent: parent_type),
    #       icon: :move
    #     }
    #   ).tab
    # end

    def adjust_description_permissions_tab(description, type, admin)
      return unless admin && type == :name

      InternalLink::Model.new(
        :show_description_adjust_permissions.t, description,
        add_query_param(
          send(:"edit_permissions_#{type}_description_path", description.id)
        ),
        html_options: { help: :show_description_adjust_permissions_help.l,
                        icon: :adjust }
      ).tab
    end

    def make_description_default_tab(description, type)
      return unless description.public && User.current &&
                    (description.parent.description_id != description.id)

      InternalLink::Model.new(
        :show_description_make_default.t, description,
        add_query_param(
          send(:"make_default_#{type}_description_path", description.id)
        ),
        html_options: { button: :put,
                        help: :show_description_make_default_help.l,
                        icon: :make_default }
      ).tab
    end

    def description_project_tab(description)
      return unless (description.source_type == "project") &&
                    (project = description.source_object)

      InternalLink::Model.new(
        :show_object.t(type: :project), description,
        add_query_param(project.show_link_args),
        html_options: { icon: :project }
      ).tab
    end

    def publish_description_draft_tab(description, type, admin)
      return unless admin && (type == :name) &&
                    (description.source_type != :public)

      InternalLink::Model.new(
        :show_description_publish.t, description,
        add_query_param(
          send(:"publish_#{type}_description_path", description.id)
        ),
        html_options: { button: :put, help: :show_description_publish_help.l,
                        icon: :publish }
      ).tab
    end

    def new_description_for_project_tab(object, type, project)
      InternalLink::Model.new(
        project.title, "#{type.capitalize}Description",
        add_query_param(
          send(:"new_#{type}_description_path",
               { project: project.id, source: "project",
                 "#{type}_id": object.id })
        )
      ).tab
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
