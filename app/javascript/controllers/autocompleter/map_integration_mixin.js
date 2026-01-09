/**
 * MapIntegrationMixin - Handles map outlet integration for location autocompleters
 *
 * This mixin provides functionality for autocompleters that interact with
 * a map controller outlet (location_google, location_containing types).
 *
 * Features:
 * - Activates/deactivates map outlet for location creation
 * - Handles Google geocoding refresh logic
 * - Manages "create" mode UI state
 * - Coordinates with map controller for lat/lng inputs
 *
 * Usage: Object.assign(this, MapIntegrationMixin) in controller initialize()
 */

export const MapIntegrationMixin = {
  // ---------------------- Map Outlet Management ----------------------

  // Connects autocompleter to map controller to call its methods
  activateMapOutlet(location = false) {
    if (!this.hasMapOutlet) {
      this.verbose("MapIntegrationMixin: no map outlet");
      return;
    }

    // Map controller may not be connected yet if map is collapsed
    let map;
    try {
      map = this.mapOutlet;
    } catch (e) {
      this.verbose("MapIntegrationMixin: map outlet not ready");
      return;
    }

    this.verbose("MapIntegrationMixin:activateMapOutlet()");
    // open the map if not already open
    if (!map.opened && map.hasToggleMapBtnTarget) {
      this.verbose("MapIntegrationMixin: open map");
      map.toggleMapBtnTarget.click();
    }
    // set the map type so box is editable
    map.map_type = "hybrid"; // only if location_google
    // set the map to stop ignoring place input
    map.ignorePlaceInput = false;

    // Often, this swap to location_google is for geolocating place_names and
    // should pay attention to text only. But in some cases the swap (e.g., from
    // form-exif) sends request_params lat/lng, so geocode when switching.
    if (location) {
      map.tryToGeocode();
    }
  },

  deactivateMapOutlet() {
    if (!this.hasMapOutlet) return;

    let map;
    try {
      map = this.mapOutlet;
    } catch (e) {
      return;
    }

    this.verbose("MapIntegrationMixin: deactivateMapOutlet()");
    if (map.rectangle) map.clearRectangle();
    map.map_type = "observation";

    map.northInputTarget.value = '';
    map.southInputTarget.value = '';
    map.eastInputTarget.value = '';
    map.westInputTarget.value = '';
    map.highInputTarget.value = '';
    map.lowInputTarget.value = '';
  },

  // ---------------------- Create Mode ----------------------

  swapCreate() {
    this.swap({ detail: { type: "location_google" } });
  },

  leaveCreate() {
    if (!(['location_google'].includes(this.TYPE) && this.hasMapOutlet)) return;

    let map;
    try {
      map = this.mapOutlet;
    } catch (e) {
      return;
    }

    this.verbose("MapIntegrationMixin: leaveCreate()");
    const location = map.validateLatLngInputs(false);
    // Will swap to location, or location_containing if lat/lngs are present
    if (map.ignorePlaceInput !== true) {
      map.sendPointChanged(location);
    }
  },

  // ---------------------- Google Refresh ----------------------

  // This should only refresh the primer if we don't have lat/lngs - the lat/lng
  // effectively keeps the selections. If we refresh on the string, we'll get
  // stuck with a single geolocatePlaceName result, which is only ever one.
  // If we don't have lat/lngs, just draw the pulldown.
  scheduleGoogleRefresh() {
    let map;
    try {
      map = this.hasMapOutlet ? this.mapOutlet : null;
    } catch (e) {
      map = null;
    }

    if (map &&
      map.hasLatInputTarget &&
      map.hasLngInputTarget &&
      map.latInputTarget.value &&
      map.lngInputTarget.value) {
      this.drawPulldown();
      return;
    }

    this.verbose("MapIntegrationMixin:scheduleGoogleRefresh()");
    this.clearRefresh();
    this.refresh_timer = setTimeout((() => {
      const current_input = this.inputTarget.value;
      this.verbose("MapIntegrationMixin: doing google refresh");
      this.verbose(current_input);
      this.old_value = current_input;
      // async, anything after this executes immediately
      // STORE AND COMPARE SEARCH STRING. Otherwise we're doing double lookups
      if (this.hasGeocodeOutlet) {
        this.geocodeOutlet.tryToGeolocate(current_input);
      } else if (map) {
        map.tryToGeolocate(current_input);
      }
    }), this.REFRESH_DELAY * 1000);
  },

  // Map controller sends back a primer formatted for the autocompleter
  refreshGooglePrimer({ primer }) {
    // Ensure primer is processed even if input lost focus (e.g., after clicking
    // "New locality" button). processFetchResponse checks this.focused.
    this.focused = true;
    this.processFetchResponse(primer)
  },

  // ---------------------- UI State ----------------------

  // Depending on the type of autocompleter, the UI may need to change.
  // detail may also contain request_params for lat/lng.
  constrainedSelectionUI(location = false) {
    if (this.TYPE === "location_google") {
      this.verbose("MapIntegrationMixin: swapped to location_google");
      this.element.classList.add('create');
      this.element.classList.remove('offer-create');
      this.element.classList.remove('constrained');
      if (this.hasMapWrapTarget) {
        this.mapWrapTarget.classList.remove('d-none');
      } else {
        this.verbose("MapIntegrationMixin: no map wrap");
      }
      this.activateMapOutlet(location);
    } else if (this.ACT_LIKE_SELECT) {
      this.verbose("MapIntegrationMixin: swapped to ACT_LIKE_SELECT");
      this.deactivateMapOutlet();
      // primer is not based on input, so go ahead and request from server.
      this.focused = true; // so it will draw the pulldown immediately
      this.refreshPrimer(); // directly refresh the primer w/request_params
      this.element.classList.add('constrained');
      this.element.classList.remove('create');
    } else {
      this.verbose("MapIntegrationMixin: swapped regular");
      this.deactivateMapOutlet();
      this.scheduleRefresh();
      this.element.classList.remove('constrained', 'create');
    }
  },

  // only clear if we're not in "ignorePlaceInput" mode
  ignoringTextInput() {
    if (!this.hasMapOutlet) return false;

    let map;
    try {
      map = this.mapOutlet;
    } catch (e) {
      return false;
    }

    this.verbose("MapIntegrationMixin:ignoringTextInput()");
    return map.ignorePlaceInput;
  },

  // Reset ignorePlaceInput when user manually edits location text.
  // This allows breaking out of EXIF-constrained mode by typing.
  resetIgnorePlaceInput() {
    if (!this.hasMapOutlet) return;

    let map;
    try {
      map = this.mapOutlet;
    } catch (e) {
      return;
    }

    if (map.ignorePlaceInput) {
      this.verbose("MapIntegrationMixin:resetIgnorePlaceInput()");
      map.ignorePlaceInput = false;
    }
  }
};

export default MapIntegrationMixin;
