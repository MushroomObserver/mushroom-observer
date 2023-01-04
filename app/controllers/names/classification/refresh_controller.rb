# frozen_string_literal: true

# inherit_classification
module Names::Classification
  class RefreshController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching

    # PUT callback
    def refresh_classification
      pass_query_params
      name = find_or_goto_index(Name, params[:id])
      return unless name
      return unless make_sure_name_below_genus!(name)
      return unless make_sure_genus_has_classification!(name)

      name.update(classification: name.accepted_genus.classification)
      desc = name.description
      desc&.update(classification: name.accepted_genus.classification)
      redirect_with_query(name.show_link_args)
    end

    include Names::Classification::SharedPrivateMethods
  end
end
