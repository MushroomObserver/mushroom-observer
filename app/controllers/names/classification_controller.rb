# frozen_string_literal: true

#  == CLASSIFICATIONS
#  propagate_classification::    Copy classification to all subtaxa.
#  refresh_classification::      Refresh classification from genus.
#  inherit_classification::
#  edit_classification::
#
module Names
  class ClassificationController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching

    def edit_classification
      store_location
      pass_query_params
      @name = find_or_goto_index(Name, params[:id])
      return unless @name
      return unless request.method == "POST"

      @name.classification = params[:classification].to_s.strip_html.
                             strip_squeeze
      return unless validate_classification!

      @name.change_classification(@name.classification)
      redirect_with_query(@name.show_link_args)
    end

    include Names::Classification::SharedPrivateMethods
  end
end
