import BaseAutocompleterController from "./base_controller"

/**
 * SpeciesListController - Autocompleter for SpeciesList records
 *
 * Uses unordered matching (words can appear in any order).
 * Example: typing "2024 foray" matches "NAMA Foray 2024"
 */
export default class SpeciesListController extends BaseAutocompleterController {
  /**
   * Type-specific configuration for species_list autocompleters.
   */
  getTypeConfig() {
    return {
      TYPE: "species_list",
      model: "species_list",
      UNORDERED: true
    }
  }

  /**
   * Uses unordered matching - words can appear in any order.
   */
  populateMatchesForType() {
    this.populateUnordered()
  }
}
