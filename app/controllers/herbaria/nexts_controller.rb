# frozen_string_literal: true

module Herbaria
  # redirect to next/prev herbarium
  class NextsController < ApplicationController
    # Find next/prev herbarium from a Query, and redirect to its show page.
    def show
      case params[:next]
      when "next"
        redirect_to_next_object(:next, Herbarium, params[:id].to_s)
      when "prev"
        redirect_to_next_object(:prev, Herbarium, params[:id].to_s)
      else
        redirect_to(herbarium_path(params[:id].to_s))
      end
    end
  end
end
