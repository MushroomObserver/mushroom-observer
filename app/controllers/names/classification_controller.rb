# frozen_string_literal: true

#  == CLASSIFICATIONS
#  edit_classification::
#
module Names
  class ClassificationController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching

    # Form
    def edit
      store_location
      pass_query_params
      return unless find_name!
    end

    # PUT callback
    def update
      store_location
      pass_query_params
      return unless find_name!

      @name.classification = params[:classification].to_s.strip_html.
                             strip_squeeze
      return unless validate_classification!

      @name.change_classification(@name.classification)
      redirect_with_query(@name.show_link_args)
    end

    include Names::Classification::SharedPrivateMethods
  end
end
