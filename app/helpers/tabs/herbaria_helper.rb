# frozen_string_literal: true

# Custom Tabset Helpers for Herbaria views
# NOTE: this uses ids not classes for identifiers, change this
module Tabs
  module HerbariaHelper
    def herbaria_index_tabs(query: nil)
      links ||= []
      links << if query&.params&.dig(:nonpersonal)
                 herbaria_index_tab
               else
                 labeled_nonpersonal_herbaria_index_tab
               end
      links << new_herbarium_tab
    end

    def herbaria_index_sorts(query: nil)
      if query&.params&.dig(:nonpersonal)
        return nonpersonal_herbaria_index_sorts
      end

      full_herbaria_index_sorts
    end

    def full_herbaria_index_sorts
      [
        ["records",     :sort_by_records.t],
        ["curator",     :sort_by_curator.t],
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

    def herbarium_show_tabs
      [nonpersonal_herbaria_index_tab]
    end

    def herbarium_form_new_tabs
      [nonpersonal_herbaria_index_tab]
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
      InternalLink::Model.new(:create_herbarium.l, Herbarium,
                              add_query_param(new_herbarium_path),
                              alt_title: "new_herbarium").tab
    end

    def edit_herbarium_tab(herbarium)
      InternalLink::Model.new(
        :edit_herbarium.l, herbarium,
        add_query_param(edit_herbarium_path(herbarium.id))
      ).tab
    end

    def destroy_herbarium_tab(herbarium)
      InternalLink::Model.new(
        :destroy_object.t(type: :herbarium),
        herbarium, herbarium,
        html_options: { button: :destroy, back: url_after_delete(herbarium) }
      ).tab
    end

    def herbaria_index_tab
      InternalLink::Model.new(
        :herbarium_index_list_all_herbaria.l, Herbarium, herbaria_path
      ).tab
    end

    def herbarium_return_tab(herbarium)
      InternalLink::Model.new(
        :cancel_and_show.t(type: :herbarium), herbarium,
        add_query_param(herbarium_path(herbarium))
      ).tab
    end

    def nonpersonal_herbaria_index_tab
      InternalLink.new(
        :herbarium_index.t,
        add_query_param(herbaria_path(nonpersonal: true)),
        alt_title: "nonpersonal_herbaria_index"
      ).tab
    end

    def labeled_nonpersonal_herbaria_index_tab
      InternalLink.new(
        :herbarium_index_nonpersonal_herbaria.l,
        herbaria_path(nonpersonal: true)
      ).tab
    end
  end
end
