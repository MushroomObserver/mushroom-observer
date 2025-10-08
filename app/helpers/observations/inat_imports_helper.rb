# frozen_string_literal: true

module Observations
  module InatImportsHelper
    include Inat::Constants

    def inat_expected_import_count(import)
      return :inat_import_tbd.l if imports_ambiguous?(import)

      query_args = {
        # obss of only the iNat user who has inat_username
        user_id: import.inat_username,
        # only fungi and slime molds
        iconic_taxa: ICONIC_TAXA,
        # and which haven't been exported from or inported to MO
        without_field: "Mushroom Observer URL",
        # always include id key to make stubbing easier
        id: nil,
        # streamline query and response; all we need is the count
        only_id: true,
        per_page: 1,
        page: 1
      }
      query_args[:id] = import.inat_ids if import.inat_ids.present?
      begin
        response = Inat::APIRequest.new(nil). # no token for GET
                   request(path: "observations?#{query_args.to_query}")
        return :inat_import_tbd.l unless response_body?(response)

        JSON.parse(response.body)["total_results"]
      rescue ::RestClient::ExceptionWithResponse
        :inat_import_tbd.l
      end
    end

    def response_body?(response)
      response.code == 200 && response.body.present?
    end
    private :response_body?

    def inat_expected_imports_link(import)
      return :inat_import_tbd.l if imports_ambiguous?(import)

      query_args = {
        # obss of only the iNat user who has inat_username
        user_login: import.inat_username,
        # only fungi and slime molds
        iconic_taxa: ICONIC_TAXA,
        # and which haven't been exported from or inported to MO
        without_field: "Mushroom Observer URL",
        # streamline query and response; all we need is the count
        only_id: true, per_page: 1
      }
      query_args[:id] = import.inat_ids if import.inat_ids.present?
      link_to(:inat_expected_imports_link.l,
              "#{SITE}/observations?#{query_args.to_query}")
    end

    private

    def imports_ambiguous?(import)
      import.inat_ids.blank? && !import.import_all? ||
        import.inat_ids.present? && import.import_all?
    end
  end
end
