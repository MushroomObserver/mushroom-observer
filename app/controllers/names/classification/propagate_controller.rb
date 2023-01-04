# frozen_string_literal: true

# inherit_classification
module Names::Classification
  class PropagateController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching

    # POST callback
    def propagate_classification
      pass_query_params
      name = find_or_goto_index(Name, params[:id])
      return unless name
      return unless make_sure_name_is_genus!(name)

      name.propagate_classification
      redirect_with_query(name.show_link_args)
    end

    include Names::Classification::SharedPrivateMethods
  end
end
