# frozen_string_literal: true

#
#  = Searchable Concern
#
#  This is a module of reusable methods included by controllers that handle
#  "faceted" query searches per model, with separate inputs for each keyword.
#  It also handles rendering help for the pattern search bar, via `:show` action
#
################################################################################

module Searchable
  extend ActiveSupport::Concern

  included do
    def show
      respond_to do |format|
        format.turbo_stream do
          render(turbo_stream: turbo_stream.update(
            :search_nav_help, # id of element to update contents of
            partial: "#{parent_controller}/search/help"
          ))
        end
        format.html
      end
    end

    private

    def parent_controller
      self.class.name.deconstantize.underscore
    end

    # Returns the capitalized :Symbol used by Query for the type of query.
    def query_model
      self.class.module_parent.name.singularize.to_sym
    end

    # Gets the query class relevant to each controller, assuming the controller
    # is namespaced like Observations::SearchController
    def query_subclass
      Query.const_get(self.class.module_parent.name)
    end

    # the underscored symbol
    def search_type
      self.class.name.deconstantize.singularize.underscore.to_sym
    end
  end
end
