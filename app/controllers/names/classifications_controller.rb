# frozen_string_literal: true

#  == CLASSIFICATIONS
#  propagate_classification::    Copy classification to all subtaxa.
#  refresh_classification::      Refresh classification from genus.
#  inherit_classification::
#  edit_classification::
#
module Names
  class ClassificationsController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching

    def propagate_classification
      pass_query_params
      name = find_or_goto_index(Name, params[:id])
      return unless name
      return unless make_sure_name_is_genus!(name)

      name.propagate_classification
      redirect_with_query(name.show_link_args)
    end

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

    def edit_classification
      store_location
      pass_query_params
      @name = find_or_goto_index(Name, params[:id])
      return unless @name
      return unless request.method == "POST"

      @name.classification = params[:classification].to_s.strip_html.strip_squeeze
      return unless validate_classification!

      @name.change_classification(@name.classification)
      redirect_with_query(@name.show_link_args)
    end

    # --------------------------------------------------------------------------
    include Names::Classifications::SharedPrivateMethods
  end
end
