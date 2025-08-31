# frozen_string_literal: true

# html used in tabsets
module Tabs
  module NamingsHelper
    def new_naming_tab(obs_id, text:, context:, btn_class:)
      InternalLink::Model.new(
        text, Naming,
        new_observation_naming_path(observation_id: obs_id, context: context),
        html_options: {
          class: class_names(btn_class, %w[propose-naming-link]),
          icon: :add
        }
      ).tab
    end

    def edit_naming_tab(naming)
      InternalLink::Model.new(
        :EDIT.l, naming,
        edit_observation_naming_path(
          observation_id: naming.observation_id, id: naming.id
        ),
        html_options: { icon: :edit }
      ).tab
    end
  end
end
