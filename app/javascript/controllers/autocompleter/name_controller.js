import BaseAutocompleterController, {
  AUTOCOMPLETER_TARGETS, AUTOCOMPLETER_OUTLETS
} from "./base_controller"

/**
 * NameAutocompleterController - Autocompleter for Name (taxon) records
 *
 * Uses collapsed matching strategy - autocompletes word by word.
 * First completes genus, then species, then variety, etc.
 * Example: "Agar" → "Agaricus " → "Agaricus camp" → "Agaricus campestris"
 *
 * Word matching: After WORD_MATCH_THRESHOLD characters, the server switches
 * from beginning-of-name matching to any-word matching. This allows queries
 * like "corti" to find both "Cortinarius" and "Amanita corticola".
 */
export default class NameAutocompleterController extends BaseAutocompleterController {
  // Must redeclare static properties - JavaScript doesn't inherit them
  static targets = AUTOCOMPLETER_TARGETS
  static outlets = AUTOCOMPLETER_OUTLETS

  // Must match WORD_MATCH_THRESHOLD in Autocomplete::ForName
  static WORD_MATCH_THRESHOLD = 4

  /**
   * Type-specific configuration for name autocompleters.
   */
  getTypeConfig() {
    return {
      TYPE: "name",
      model: "name",
      COLLAPSE: 1
    }
  }

  /**
   * Uses collapsed matching - autocompletes word by word.
   */
  populateMatchesForType() {
    this.populateCollapsed()
  }

  /**
   * Override refreshPrimer to force re-fetch when crossing word-match threshold.
   * When query length crosses from <4 to >=4 chars, the server switches from
   * beginning-match to word-match, so we need a fresh primer with different data.
   */
  refreshPrimer() {
    const token = this.getSearchToken().toLowerCase();
    const lastLen = this.last_fetch_request?.length || 0;
    const threshold = NameAutocompleterController.WORD_MATCH_THRESHOLD;

    // Force re-fetch if crossing the word-match threshold
    if (lastLen < threshold && token.length >= threshold) {
      this.verbose("name autocompleter: crossing word-match threshold, " +
                   "clearing primer cache");
      this.last_fetch_request = "";
      this.primer = [];
    }

    super.refreshPrimer();
  }
}
