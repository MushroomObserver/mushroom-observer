# frozen_string_literal: true

# Custom View Helpers for Herbarium Records views
#
module Tabs
  module HerbariumRecordsHelper
    include HerbariaHelper
    def herbarium_records_index_links(obs:)
      links = []
      if obs.present?
        links = [
          object_return_link(obs),
          new_herbarium_record_link
        ]
      end
      links << new_herbarium_link
      links << nonpersonal_herbaria_index_link
    end

    def herbarium_records_index_sorts
      [
        ["herbarium_name",  :sort_by_herbarium_name.t],
        ["herbarium_label", :sort_by_herbarium_label.t],
        ["created_at",      :sort_by_created_at.t],
        ["updated_at",      :sort_by_updated_at.t]
      ].freeze
    end

    def herbarium_record_show_links(h_r:)
      links = []
      if in_admin_mode? || h_r.can_edit?
        links.push(
          edit_herbarium_record_link(h_r),
          destroy_herbarium_record_link(h_r)
        )
      end
      links << nonpersonal_herbaria_index_link
      links
    end

    def herbarium_record_form_new_links(obs:)
      [
        object_return_link(obs),
        new_herbarium_link,
        nonpersonal_herbaria_index_link
      ]
    end

    def herbarium_record_form_edit_links(back:, back_object:)
      links = []
      if back == "index"
        links << herbarium_records_index_return_link
      elsif back_object
        links << object_return_link(back_object)
      end
      links << new_herbarium_link
      links << nonpersonal_herbaria_index_link
    end

    def new_herbarium_record_link
      [:create_herbarium_record.l,
       new_herbarium_record_path(id: params[:id]),
       { class: __method__.to_s }]
    end

    def edit_herbarium_record_link(h_r)
      [:edit_herbarium_record.t,
       add_query_param(edit_herbarium_record_path(h_r.id, back: :show)),
       { class: __method__.to_s }]
    end

    def destroy_herbarium_record_link(h_r)
      [:destroy_object.t(type: :herbarium_record), h_r, { button: :destroy }]
    end

    def herbarium_records_index_return_link
      [:edit_herbarium_record_back_to_index.t,
       herbarium_records_path(q: get_query_param),
       { class: __method__.to_s }]
    end
  end
end
