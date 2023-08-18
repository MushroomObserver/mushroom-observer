# frozen_string_literal: true

# Custom Tabset Helpers for Herbaria views
# NOTE: this uses ids not classes for identifiers, change this
module Tabs
  module HerbariaHelper
    def herbaria_index_links(query:)
      links ||= []
      links << herbaria_index_link unless query&.flavor == :all
      unless query&.flavor == :nonpersonal
        links << labeled_nonpersonal_herbaria_index_link
      end
      links << new_herbarium_link
    end

    def herbaria_index_sorts
      [
        ["records",     :sort_by_records.t],
        ["user",        :sort_by_user.t],
        ["code",        :sort_by_code.t],
        ["name",        :sort_by_name.t],
        ["created_at",  :sort_by_created_at.t],
        ["updated_at",  :sort_by_updated_at.t]
      ].freeze
    end

    def herbarium_show_links(herbarium:, user:)
      tabs = []
      if herbarium.curators.empty? ||
         herbarium.curator?(user) || in_admin_mode?
        tabs += [
          edit_herbarium_link(herbarium),
          destroy_herbarium_link(herbarium)
        ]
      end
      tabs += [
        new_herbarium_link,
        nonpersonal_herbaria_index_link
      ]
      tabs
    end

    def herbarium_form_new_links
      nonpersonal_herbaria_index_link
    end

    def herbarium_form_edit_links(herbarium:)
      [
        herbarium_return_link(herbarium),
        nonpersonal_herbaria_index_link
      ]
    end

    def herbaria_curator_request_links(herbarium:)
      [
        herbarium_return_link(herbarium),
        nonpersonal_herbaria_index_link
      ]
    end

    def new_herbarium_link
      [:create_herbarium.t, add_query_param(new_herbarium_path),
       { class: __method__.to_s }]
    end

    def edit_herbarium_link(herbarium)
      [:edit_herbarium.t,
       add_query_param(edit_herbarium_path(herbarium.id)),
       { class: __method__.to_s }]
    end

    def destroy_herbarium_link(herbarium)
      [:destroy_object.t(type: :herbarium),
       herbarium,
       { button: :destroy, back: url_after_delete(herbarium) }]
    end

    def herbaria_index_link
      [:herbarium_index_list_all_herbaria.l,
       herbaria_path(flavor: :all),
       { class: __method__.to_s }]
    end

    def herbarium_return_link(herbarium)
      [:cancel_and_show.t(type: :herbarium),
       add_query_param(herbarium_path(herbarium)),
       { class: __method__.to_s }]
    end

    def nonpersonal_herbaria_index_link
      [:herbarium_index.t,
       add_query_param(herbaria_path(flavor: :nonpersonal)),
       { class: __method__.to_s }]
    end

    def labeled_nonpersonal_herbaria_index_link
      [:herbarium_index_nonpersonal_herbaria.l,
       herbaria_path(flavor: :nonpersonal),
       { class: "nonpersonal_herbaria_index_link" }]
    end
  end
end
