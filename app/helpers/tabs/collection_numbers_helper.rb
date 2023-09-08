# frozen_string_literal: true

module Tabs
  module CollectionNumbersHelper
    def collection_number_show_tabs(c_n:)
      return [] unless in_admin_mode? || c_n.can_edit?

      collection_number_mod_tabs(c_n)
    end

    def collection_numbers_index_tabs(obs:)
      return [] if obs.blank?

      [
        object_return_tab(obs),
        new_collection_number_for_obs_tab(obs)
      ]
    end

    def collection_numbers_index_sorts
      [
        ["name",       :sort_by_name.t],
        ["number",     :sort_by_number.t],
        ["created_at", :sort_by_created_at.t],
        ["updated_at", :sort_by_updated_at.t]
      ].freeze
    end

    def collection_number_form_new_tabs(obs:)
      [object_return_tab(obs)]
    end

    def collection_number_form_new_title
      :create_collection_number_title.l
    end

    def collection_number_form_edit_tabs(c_n:, back:, obj:)
      links = []
      links << if back == "index"
                 collection_numbers_index_tab(c_n)
               else
                 object_return_tab(obj)
               end
    end

    def collection_number_form_edit_title(c_n:)
      :edit_collection_number_title.l(name: c_n.format_name)
    end

    def collection_numbers_index_tab(c_n)
      [:edit_collection_number_back_to_index.t,
       add_query_param(c_n.index_link_args),
       { class: tab_id(__method__.to_s) }]
    end

    def collection_number_show_tab(c_n, obs)
      cn_query = Query.lookup(:CollectionNumber, :all, observations: obs.id)

      [tag.i(c_n.format_name.t),
       collection_number_path(id: c_n.id, q: cn_query),
       { class: "#{tab_id(__method__.to_s)}_#{c_n.id}" }]
    end

    def collection_number_mod_tabs(c_n)
      [edit_collection_number_tab(c_n),
       destroy_collection_number_tab(c_n)]
    end

    def new_collection_number_for_obs_tab(obs)
      [:create_collection_number.l,
       add_query_param(new_collection_number_path(observation_id: obs.id)),
       { class: "#{tab_id(__method__.to_s)}_#{obs.id}" }]
    end

    def edit_collection_number_tab(c_n)
      [:edit_collection_number.t,
       add_query_param(edit_collection_number_path(id: c_n.id, back: :show)),
       { class: "#{tab_id(__method__.to_s)}_#{c_n.id}" }]
    end

    def destroy_collection_number_tab(c_n)
      [:delete_collection_number.t, c_n, { button: :destroy }]
    end
  end
end
