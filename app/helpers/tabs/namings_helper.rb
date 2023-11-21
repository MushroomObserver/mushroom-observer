# frozen_string_literal: true

# html used in tabsets
module Tabs
  module NamingsHelper
    def new_naming_tab(obs_id, text:, context:, btn_class:)
      [text,
       add_query_param(
         new_observation_naming_path(observation_id: obs_id, context: context)
       ),
       { class: class_names("#{tab_id(__method__.to_s)}_#{obs_id}", btn_class,
                            %w[btn d-inline-block propose-naming-link]) }]
    end

    def edit_naming_tab(naming)
      [:EDIT.l,
       add_query_param(edit_naming_path(id: naming.id)),
       { class: "#{tab_id(__method__.to_s)}_#{naming.id}", icon: :edit }]
    end
  end
end
