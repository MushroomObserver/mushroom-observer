# frozen_string_literal: true

require("test_helper")

module SpeciesLists
  class NameListsControllerTest < FunctionalTestCase
    # ----------------------------
    #  Name lister and reports.
    # ----------------------------

    def test_name_lister
      # This will have to be very rudimentary, since the vast majority of the
      # complexity is in Javascript.  Sigh.
      user = login("rolf")
      assert(user.successful_contributor?)
      get(:new)

      params = {
        results: [
          "Amanita baccata|sensu Borealis*",
          "Coprinus comatus*",
          "Fungi*",
          "Lactarius alpigenes"
        ].join("\n")
      }

      post(:create,
           params: params.merge(commit: :name_lister_submit_spl.l))
      ids = @controller.instance_variable_get(:@names).map(&:id)
      assert_equal([names(:amanita_baccata_borealis).id,
                    names(:coprinus_comatus).id, names(:fungi).id,
                    names(:lactarius_alpigenes).id],
                   ids)
      assert_create_species_list

      path = Rails.root.join("test/reports")

      post(:create,
           params: params.merge(commit: :name_lister_submit_csv.l))
      assert_response_equal_file(["#{path}/test2.csv", "ISO-8859-1"])

      post(:create,
           params: params.merge(commit: :name_lister_submit_txt.l))
      assert_response_equal_file("#{path}/test2.txt")

      post(:create,
           params: params.merge(commit: :name_lister_submit_rtf.l))
      assert_response_equal_file("#{path}/test2.rtf") do |x|
        x.sub(/\{\\createim\\yr.*\}/, "")
      end

      post(:create, params: { commit: "bogus" })
      assert_flash_error
      assert_template("new")
    end

    def assert_create_species_list
      assert_template("species_lists/new")
      assert_template("shared/_form_list_feedback")
      assert_template("shared/_textilize_help")
      assert_template("species_lists/_form")
    end
  end
end
