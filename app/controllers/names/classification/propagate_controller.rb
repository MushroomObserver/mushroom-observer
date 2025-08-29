# frozen_string_literal: true

# propagate_classification
module Names::Classification
  class PropagateController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    # PUT callback
    def update
      return unless find_name!
      return unless make_sure_name_is_genus!(@name)

      @name.propagate_classification
      redirect_to(@name.show_link_args)
    end

    include Names::Classification::SharedPrivateMethods
  end
end
