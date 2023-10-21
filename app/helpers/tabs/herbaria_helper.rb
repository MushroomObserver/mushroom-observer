# frozen_string_literal: true

# Custom Tabset Helpers for Herbaria views
# NOTE: this uses ids not classes for identifiers, change this
module Tabs
  module HerbariaHelper
    def herbaria_index_tabs(query:)
      links ||= []
      links << herbaria_index_tab unless query&.flavor == :all
      unless query&.flavor == :nonpersonal
        links << labeled_nonpersonal_herbaria_index_tab
      end
      links << new_herbarium_tab
    end

    def herbaria_index_sorts(query:)
      return nonpersonal_herbaria_index_sorts if query&.flavor == :nonpersonal

      full_herbaria_index_sorts
    end

    def full_herbaria_index_sorts
      [
        ["records",     :sort_by_records.t],
        ["user",        :sort_by_user.t],
        ["code",        :sort_by_code.t],
        ["name",        :sort_by_name.t],
        ["created_at",  :sort_by_created_at.t],
        ["updated_at",  :sort_by_updated_at.t]
      ].freeze
    end

    def nonpersonal_herbaria_index_sorts
      # must dup a frozen array, this is new ruby 3 policy
      sorts = full_herbaria_index_sorts.map(&:clone)
      sorts.reject! { |x| x[0] == "user" }
    end

    def herbarium_show_tabs(herbarium:, user:)
      tabs = []
      if herbarium.curators.empty? ||
         herbarium.curator?(user) || in_admin_mode?
        tabs += [
          edit_herbarium_tab(herbarium),
          destroy_herbarium_tab(herbarium)
        ]
      end
      tabs += [
        new_herbarium_tab,
        nonpersonal_herbaria_index_tab
      ]
      tabs
    end

    def herbarium_form_new_tabs
      nonpersonal_herbaria_index_tab
    end

    def herbarium_form_edit_tabs(herbarium:)
      [
        herbarium_return_tab(herbarium),
        nonpersonal_herbaria_index_tab
      ]
    end

    def herbaria_curator_request_tabs(herbarium:)
      [
        herbarium_return_tab(herbarium),
        nonpersonal_herbaria_index_tab
      ]
    end

    def new_herbarium_tab
      [:create_herbarium.t, add_query_param(new_herbarium_path),
       { class: tab_id(__method__.to_s) }]
    end

    def edit_herbarium_tab(herbarium)
      [:edit_herbarium.t,
       add_query_param(edit_herbarium_path(herbarium.id)),
       { class: tab_id(__method__.to_s) }]
    end

    def destroy_herbarium_tab(herbarium)
      [:destroy_object.t(type: :herbarium),
       herbarium,
       { button: :destroy, back: url_after_delete(herbarium) }]
    end

    def herbaria_index_tab
      [:herbarium_index_list_all_herbaria.l,
       herbaria_path(flavor: :all),
       { class: tab_id(__method__.to_s) }]
    end

    def herbarium_return_tab(herbarium)
      [:cancel_and_show.t(type: :herbarium),
       add_query_param(herbarium_path(herbarium)),
       { class: tab_id(__method__.to_s) }]
    end

    def nonpersonal_herbaria_index_tab
      [:herbarium_index.t,
       add_query_param(herbaria_path(flavor: :nonpersonal)),
       { class: tab_id(__method__.to_s) }]
    end

    def labeled_nonpersonal_herbaria_index_tab
      [:herbarium_index_nonpersonal_herbaria.l,
       herbaria_path(flavor: :nonpersonal),
       { class: "nonpersonal_herbaria_index_link" }]
    end
  end
end
