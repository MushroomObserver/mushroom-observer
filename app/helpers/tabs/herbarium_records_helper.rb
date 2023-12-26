# frozen_string_literal: true

# Custom View Helpers for Herbarium Records views
#
module Tabs
  module HerbariumRecordsHelper
    include HerbariaHelper
    def herbarium_records_index_tabs(obs:)
      links = []
      if obs.present?
        links = [
          object_return_tab(obs),
          new_herbarium_record_tab
        ]
      end
      links << new_herbarium_tab
      links << nonpersonal_herbaria_index_tab
    end

    def herbarium_records_index_sorts
      [
        ["herbarium_name",  :sort_by_herbarium_name.t],
        ["herbarium_label", :sort_by_herbarium_label.t],
        ["created_at",      :sort_by_created_at.t],
        ["updated_at",      :sort_by_updated_at.t]
      ].freeze
    end

    def herbarium_record_show_tabs(h_r:)
      links = []
      if in_admin_mode? || h_r.can_edit?
        links.push(
          edit_herbarium_record_tab(h_r),
          destroy_herbarium_record_tab(h_r)
        )
      end
      links << nonpersonal_herbaria_index_tab
      links
    end

    def herbarium_record_form_new_title
      :create_herbarium_record_title.l
    end

    def herbarium_record_form_new_tabs(obs:)
      [
        object_return_tab(obs),
        new_herbarium_tab,
        nonpersonal_herbaria_index_tab
      ]
    end

    def herbarium_record_form_edit_title(h_r:)
      :edit_herbarium_record_title.l(
        herbarium_label: h_r.herbarium_label
      )
    end

    def herbarium_record_form_edit_tabs(back:, back_object:)
      links = []
      if back == "index"
        links << herbarium_records_index_return_tab
      elsif back_object
        links << object_return_tab(back_object)
      end
      links << new_herbarium_tab
      links << nonpersonal_herbaria_index_tab
    end

    def show_herbarium_record_tab(h_r)
      [h_r.accession_at_herbarium.t,
       herbarium_record_path(id: h_r.id, q: get_query_param),
       { class: "#{tab_id(__method__.to_s)}_#{h_r.id}" }]
    end

    def new_herbarium_record_tab
      [:create_herbarium_record.l,
       new_herbarium_record_path(observation_id: params[:id]),
       { class: tab_id(__method__.to_s), icon: :add }]
    end

    def edit_herbarium_record_tab(h_r, obs = nil)
      back = obs&.id || :show
      [:edit_herbarium_record.t,
       add_query_param(edit_herbarium_record_path(h_r.id, back: back)),
       { class: "#{tab_id(__method__.to_s)}_#{h_r.id}", icon: :edit }]
    end

    def destroy_herbarium_record_tab(h_r)
      [:destroy_object.t(type: :herbarium_record), h_r,
       { button: :destroy, icon: :delete }]
    end

    def herbarium_records_index_return_tab
      [:edit_herbarium_record_back_to_index.t,
       herbarium_records_path(q: get_query_param),
       { class: tab_id(__method__.to_s) }]
    end

    def remove_herbarium_record_tab(h_r, obs)
      [:REMOVE.t,
       add_query_param(edit_herbarium_record_remove_observation_path(
                         herbarium_record_id: h_r.id, observation_id: obs.id
                       )),
       { class: "#{tab_id(__method__.to_s)}_#{h_r.id}", icon: :remove }]
    end
  end
end
