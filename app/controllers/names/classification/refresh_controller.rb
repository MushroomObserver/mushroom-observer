# frozen_string_literal: true

# refresh_classification
module Names::Classification
  class RefreshController < ApplicationController
    before_action :login_required

    # PUT callback
    def update
      pass_query_params
      return unless find_name!
      return unless make_sure_name_below_genus!(@name)
      return unless make_sure_genus_has_classification!(@name)

      @name.update(classification: @name.accepted_genus.classification)
      desc = @name.description
      desc&.update(classification: @name.accepted_genus.classification)
      redirect_with_query(@name.show_link_args)
    end

    include Names::Classification::SharedPrivateMethods
  end
end
