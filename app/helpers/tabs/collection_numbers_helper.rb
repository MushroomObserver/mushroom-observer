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
        new_collection_number_tab(obs)
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

    def show_collection_number_tab(c_n, obs)
      # This is passed in to show_collection_number, allowing users to do prev,
      # next and index from there to navigate through all the rest for this obs.
      cn_query = Query.lookup(:CollectionNumber, :all, observations: obs.id)

      [tag.i(c_n.format_name.t), add_query_param(c_n.show_link_args, cn_query),
       { class: "#{tab_id(__method__.to_s)}_#{c_n.id}" }]
    end

    def collection_number_mod_tabs(c_n)
      [edit_collection_number_tab(c_n),
       destroy_collection_number_tab(c_n)]
    end

    # These should just be ADD, EDIT, and DELETE.
    def new_collection_number_tab(obs)
      [:create_collection_number.l,
       add_query_param(new_collection_number_path(observation_id: obs.id)),
       { class: tab_id(__method__.to_s), icon: :add }]
    end

    def edit_collection_number_tab(c_n, obs = nil)
      back = obs&.id || :show
      [:edit_collection_number.l,
       add_query_param(edit_collection_number_path(id: c_n.id, back: back)),
       { class: "#{tab_id(__method__.to_s)}_#{c_n.id}", icon: :edit }]
    end

    def destroy_collection_number_tab(c_n)
      [:delete_collection_number.t, c_n, { button: :destroy, icon: :delete }]
    end

    # def collection_number_remove_obs_tab(c_n, obs)
    #   [:REMOVE.t,
    #    add_query_param(collection_number_remove_observation_path(
    #                      collection_number_id: c_n.id, observation_id: obs.id
    #                    )),
    #    { class: "#{tab_id(__method__.to_s)}_#{c_n.id}", icon: :remove,
    #      method: :patch, data: { confirm: :are_you_sure.t } }]
    # end

    def remove_collection_number_tab(c_n, obs)
      [:REMOVE.t,
       add_query_param(edit_collection_number_remove_observation_path(
                         collection_number_id: c_n.id, observation_id: obs.id
                       )),
       { class: "#{tab_id(__method__.to_s)}_#{c_n.id}", icon: :remove }]
    end
  end
end
