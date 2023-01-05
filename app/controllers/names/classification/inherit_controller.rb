# frozen_string_literal: true

# inherit_classification
module Names::Classification
  class InheritController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching

    # form
    def new
      store_location
      pass_query_params
      return unless find_name!
      return unless make_sure_name_is_at_or_above_genus!(@name)
    end

    # POST callback
    def create
      store_location
      pass_query_params

      return unless find_name!
      return unless make_sure_name_is_at_or_above_genus!(@name)

      @parent_text_name = params[:parent].to_s.strip_html.strip_squeeze
      parent = resolve_name!(@parent_text_name, params[:options])
      return unless parent
      return unless make_sure_parent_has_classification!(parent)
      return unless make_sure_parent_higher_rank!(parent)

      @name.inherit_classification(parent)
      redirect_with_query(@name.show_link_args)
    end

    include Names::Classification::SharedPrivateMethods
  end
end
