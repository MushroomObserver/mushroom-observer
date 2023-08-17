# frozen_string_literal: true

# propagate_classification
module Names::Classification
  class PropagateController < ApplicationController
    before_action :login_required

    # PUT callback
    def update
      pass_query_params
      return unless find_name!
      return unless make_sure_name_is_genus!(@name)

      @name.propagate_classification
      redirect_with_query(@name.show_link_args)
    end

    include Names::Classification::SharedPrivateMethods
  end
end
