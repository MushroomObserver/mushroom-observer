# frozen_string_literal: true

# refresh_classification
module Names::Classification
  class RefreshController < ApplicationController
    before_action :login_required

    # PUT callback. Description-mirror write went away with the column
    # itself (discussion #4163) — only the Name needs updating now.
    def update
      return unless find_name!
      return unless make_sure_name_below_genus!(@name)
      return unless make_sure_genus_has_classification!(@name)

      @name.update(classification: @name.accepted_genus.classification)
      redirect_to(@name.show_link_args)
    end

    include Names::Classification::SharedPrivateMethods
  end
end
