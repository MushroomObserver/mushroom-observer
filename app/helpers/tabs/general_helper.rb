# frozen_string_literal: true

module Tabs
  module GeneralHelper
    # The tab definitions migrated to PORO classes:
    # - `Tab::Object::Return`, `Tab::Object::Show`,
    #   `Tab::Object::ShowParent`, `Tab::Object::Index` for the four
    #   polymorphic "act on any object" tabs
    # - `Tab::ExternalSearch` for the parameterized external search
    #   link (Google_Maps / Google_Search / Wikipedia)
    #
    # The methods below remain as thin legacy-shape adapters so
    # existing helper-chain callers (Phlex views, ERB templates,
    # and other `Tabs::*Helper` methods that compose this one)
    # keep working unchanged. Each PR that migrates a downstream
    # domain (observations, names, locations) replaces these calls
    # with direct PORO instantiation; once all downstream callers
    # migrate, this file can be deleted.

    def search_tab_for(site_symbol, search_string)
      return unless ::Tab::ExternalSearch::URLS.key?(site_symbol)

      ::Tab::ExternalSearch.new(site: site_symbol,
                                query: search_string).to_a
    end

    def external_search_urls
      ::Tab::ExternalSearch::URLS
    end

    def object_return_tab(obj, text = nil)
      ::Tab::Object::Return.new(object: obj, title: text).to_a
    end

    def show_object_tab(obj, text = nil)
      ::Tab::Object::Show.new(object: obj, title: text).to_a
    end

    def show_parent_tab(obj, text = nil)
      ::Tab::Object::ShowParent.new(object: obj, title: text).to_a
    end

    def object_index_tab(obj, text = nil)
      ::Tab::Object::Index.new(object: obj, q_param: q_param,
                               title: text).to_a
    end
  end
end
