# frozen_string_literal: true

module Tabs
  module CollectionNumbersHelper
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

    def collection_number_form_edit_tabs(c_n:, back:, obj:)
      links = []
      links << if back == "index"
                 collection_numbers_index_tab(c_n)
               else
                 object_return_tab(obj)
               end
    end

    def collection_numbers_index_tab(c_n)
      InternalLink::Model.new(
        :edit_collection_number_back_to_index.t, c_n,
        add_query_param(c_n.index_link_args)
      ).tab
    end

    def show_collection_number_tab(c_n, obs)
      # This is passed in to show_collection_number, allowing users to do prev,
      # next and index from there to navigate through all the rest for this obs.
      cn_query = Query.lookup(:CollectionNumber, observations: obs.id)

      InternalLink::Model.new(
        tag.i(c_n.format_name.t), c_n,
        add_query_param(c_n.show_link_args, cn_query)
      ).tab
    end

    # These should just be ADD, EDIT, and DELETE.
    def new_collection_number_tab(obs)
      InternalLink::Model.new(
        :create_collection_number.l, CollectionNumber,
        new_collection_number_path(observation_id: obs.id),
        html_options: { icon: :add }
      ).tab
    end

    def edit_collection_number_tab(c_n, obs = nil)
      back = obs&.id || :show
      InternalLink::Model.new(
        :edit_collection_number.l, c_n,
        edit_collection_number_path(id: c_n.id, back: back),
        html_options: { icon: :edit }
      ).tab
    end

    def destroy_collection_number_tab(c_n)
      InternalLink::Model.new(
        :delete_collection_number.t, c_n, c_n,
        html_options: { button: :destroy, icon: :delete }
      ).tab
    end

    # Dead code?
    # def collection_number_remove_obs_tab(c_n, obs)
    #   [:REMOVE.t,
    #    collection_number_remove_observation_path(
    #      collection_number_id: c_n.id, observation_id: obs.id
    #    ),
    #    { class: "#{tab_id(__method__.to_s)}_#{c_n.id}", icon: :remove,
    #      method: :patch, data: { confirm: :are_you_sure.t } }]
    # end

    def remove_collection_number_tab(c_n, obs)
      InternalLink::Model.new(
        :REMOVE.t, c_n,
        edit_collection_number_remove_observation_path(
          collection_number_id: c_n.id, observation_id: obs.id
        ),
        html_options: { icon: :remove }
      ).tab
    end
  end
end
