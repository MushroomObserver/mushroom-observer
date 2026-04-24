import GeocodeController from "controllers/geocode_controller"
import { Loader } from "@googlemaps/js-api-loader"
import { MarkerClusterer, SuperClusterAlgorithm } from "@googlemaps/markerclusterer"

// Connects to data-controller="map"
// The connected element can be a map, or in the case of a form with a map UI,
// the whole section of the form including the inputs that should alter the map.
// Either way, mapDivTarget should have the dataset, not the connected element.
// map_types: info (collection), location (rectangle), observation (marker)
export default class extends GeocodeController {
  // it may or may not be the root element of the controller.
  static targets = ["mapDiv", "southInput", "westInput", "northInput",
    "eastInput", "highInput", "lowInput", "placeInput", "locationId",
    "getElevation", "mapClearBtn", "controlWrap", "toggleMapBtn",
    "latInput", "lngInput", "altInput", "showBoxBtn", "lockBoxBtn",
    "editBoxBtn", "autocompleter"]

  connect() {
    this.element.dataset.map = "connected"
    this.map_type = this.mapDivTarget.dataset.mapType
    this.editable = (this.mapDivTarget.dataset.editable === "true")
    this.opened = this.element.dataset.mapOpen === "true"
    this.marker = null // Only gets set if we're in edit mode
    this.rectangle = null // Only gets set if we're in edit mode
    this.location_format = this.mapDivTarget.dataset.locationFormat
    this.marker_color = "#D95040"
    this.LOCATION_API_URL = "/api2/locations/"

    // Optional data that needs parsing
    this.collection = this.mapDivTarget.dataset.collection
    if (this.collection)
      this.collection = JSON.parse(this.collection)
    // Dynamic-clustering mode (#4159). When true, each collection set
    // is a singleton and the client wraps them in a MarkerClusterer
    // that regroups them at each zoom level.
    this.clustering = this.mapDivTarget.dataset.clustering === "true"
    this.cluster_markers = []
    this.markerClusterer = null
    // Initial fetch was capped — if so, refetching for smaller
    // viewports exposes obs that were truncated. Tracked as the
    // "last fetch" state so pans/zooms that expand or narrow the
    // viewport know whether to re-request from the server (#4159).
    this.lastFetchedCapped =
      this.mapDivTarget.dataset.capped === "true"
    this.lastFetchedBounds = null
    this.refetchTimer = 0
    this.refetchInFlight = null
    // Refetch deferral (#4159): clearing overlays in the middle of
    // reading a popup is jarring, so we park the refetch while an
    // InfoWindow is open and flush it on close.
    this.activeInfoWindow = null
    this.refetchPending = false
    this.localized_text = this.mapDivTarget.dataset.localization
    if (this.localized_text)
      this.localized_text = JSON.parse(this.localized_text)
    this.controls = this.mapDivTarget.dataset.controls
    if (this.controls)
      this.controls = JSON.parse(this.controls)

    // These private vars are for keeping track of user inputs to a form
    // that should update the form after a timeout.
    this.old_location = null
    this.marker_draw_buffer = 0
    this.autocomplete_buffer = 0
    this.geolocate_buffer = 0
    this.marker_edit_buffer = 0
    this.rectangle_edit_buffer = 0
    this.ignorePlaceInput = false
    this.lastGeocodedLatLng = { lat: null, lng: null }
    this.lastGeolocatedAddress = ""

    this.libraries = ["maps", "geocoding", "marker"]
    if (this.needElevationsValue == true)
      this.libraries.push("elevation")

    const loader = new Loader({
      apiKey: "AIzaSyCxT5WScc3b99_2h2Qfy5SX6sTnE1CX3FA",
      version: "quarterly",
      libraries: this.libraries
    })

    if (this.collection) {
      this.mapCenter = {
        lat: this.collection.extents.lat,
        lng: this.collection.extents.lng
      }
    } else {
      this.mapCenter = { lat: -7, lng: -47 }
    }

    // use center and zoom here
    this.mapOptions = {
      center: this.mapCenter,
      zoom: 1,
      mapTypeId: 'terrain',
      mapTypeControl: 'true'
    }

    // collection.extents is also a MapSet
    this.mapBounds = false
    if (this.collection) {
      this.mapBounds = this.boundsOf(this.collection.extents)
    }

    loader
      .load()
      .then((google) => {
        if (this.needElevationsValue == true)
          this.elevationService = new google.maps.ElevationService()
        this.geocoder = new google.maps.Geocoder()
        // Everything except the obs form map: draw the map.
        if (!(this.map_type === "observation" && this.editable)) {
          this.drawMap()
          // Defer overlays until the map is idle — that's when
          // map.getProjection() becomes available, which
          // rectangleTooSmall() needs to decide whether to render
          // a box vs. fall back to a square marker.
          google.maps.event.addListenerOnce(this.map, "idle", () => {
            this.buildOverlays()
            if (this.clustering) {
              google.maps.event.addListener(this.map, "idle", () => {
                this.scheduleViewportRefetch()
              })
            }
          })
        }
      })
      .catch((e) => {
        console.error("error loading gmaps: " + e)
      })
  }

  // Lock rectangle so it's not editable, and show this state in the icon link
  toggleBoxLock(event) {
    if (this.rectangle && this.hasLockBoxBtnTarget &&
      this.hasEditBoxBtnTarget) {
      if (this.rectangle.getEditable() === true) {
        this.rectangle.setEditable(false)
        this.rectangle.setOptions({ clickable: false })
        this.lockBoxBtnTarget.classList.add("d-none")
        this.editBoxBtnTarget.classList.remove("d-none")
      } else {
        this.rectangle.setEditable(true)
        this.rectangle.setOptions({ clickable: true })
        this.lockBoxBtnTarget.classList.remove("d-none")
        this.editBoxBtnTarget.classList.add("d-none")
      }
    }
  }

  // We don't draw the map for the create obs form on load, to save on API.
  // Always use fitBounds to properly display the location bounds, with a
  // maxZoom to prevent zooming in too close for small/point locations.
  drawMap() {
    this.verbose("map:drawMap")
    this.map = new google.maps.Map(this.mapDivTarget, this.mapOptions)
    if (this.mapBounds) {
      this.map.fitBounds(this.mapBounds)
      // Prevent excessive zoom for small locations (points or tiny areas)
      const maxZoom = 15
      google.maps.event.addListenerOnce(this.map, 'bounds_changed', () => {
        if (this.map.getZoom() > maxZoom) {
          this.map.setZoom(maxZoom)
        }
      })
    }
  }

  //
  //  COLLECTIONS: mapType "info" - Map of collapsible collection
  //

  // In a collection, each `set` represents an overlay (is_point or is_box).
  // set.center is an array [lat, lng]
  // the `key` of each set is an array [x,y,w,h]
  buildOverlays() {
    if (!this.collection) return

    this.verbose("map:buildOverlays")
    for (const [_xywh, set] of Object.entries(this.collection.sets)) {
      // Server-computed shape (#4159):
      //   "dot"       → single observation; circle marker.
      //   "square"    → multi-observation; fixed-size square marker
      //                 at the box center on info maps.
      //   "rectangle" → location-only set; bare outline rectangle at
      //                 the box extents (no center marker).
      // Fall back to the pre-#4159 extents-based decision when the
      // server didn't provide a glyph (e.g., legacy callers, editable
      // location maps).
      const glyph = set.glyph ||
                    (this.isPoint(set) ? "dot" : "square")
      if (glyph === "dot") {
        this.drawMarker(set)
      } else if (glyph === "rectangle" && !this.editable) {
        this.drawLocationOutline(set)
      } else {
        this.drawRectangle(set)
      }
    }
    if (this.clustering) this.initMarkerClusterer()
  }

  // Wrap every marker collected during buildOverlays in a
  // MarkerClusterer. The clusterer handles visibility, so markers
  // are attached to the map only at zoom levels where they aren't
  // part of a larger cluster. See #4159.
  initMarkerClusterer() {
    if (this.cluster_markers.length === 0) return

    this.markerClusterer = new MarkerClusterer({
      map: this.map,
      markers: this.cluster_markers.map((m) => m.marker),
      renderer: this.clusterRenderer(),
      // Supercluster's default maxZoom (16) breaks clusters apart
      // fully zoomed-in, which hides the count badge on stacks of
      // observations that share a single geographic point (e.g. many
      // obs at one location centroid, with no GPS or dubious GPS).
      // Google Maps' max zoom is 22; matching it keeps the "N" badge
      // visible even when the underlying data can't be separated
      // spatially (#4159).
      algorithm: new SuperClusterAlgorithm({ maxZoom: 22 }),
      // Default behavior zooms in on single click; override with a
      // popup listing the cluster's members. Zoom is exposed as a link
      // inside the popup when further zoom would actually separate
      // them (#4159).
      onClusterClick: (_event, cluster, _map) => {
        this.showClusterPopup(cluster)
      }
    })
  }

  showClusterPopup(cluster) {
    const bounds = cluster.bounds
    const markers = cluster.markers || []
    const canZoom = this.clusterCanZoomFurther(bounds)
    const color = this.aggregateClusterColor(markers)
    const outlineBox = this.computeClusterOutlineBox(markers)
    const content = this.buildClusterPopupHtml(markers, canZoom, outlineBox)

    if (this.clusterInfoWindow) this.clusterInfoWindow.close()
    this.clearFuzzyBoxOverlay()

    this.clusterInfoWindow = new google.maps.InfoWindow({
      content,
      position: cluster.position,
      maxWidth: 320
    })
    this.clusterInfoWindow.open({ map: this.map })
    this.noteInfoWindowOpened(this.clusterInfoWindow)

    if (outlineBox && this.outlineLargerThanClusterBadge(outlineBox, bounds)) {
      this.fuzzyBoxOverlay = new google.maps.Rectangle({
        strokeColor: color,
        strokeOpacity: 1,
        strokeWeight: 2,
        fillColor: color,
        fillOpacity: 0.25,
        bounds: {
          north: outlineBox.n, south: outlineBox.s,
          east: outlineBox.e, west: outlineBox.w
        },
        clickable: false,
        map: this.map
      })
    }

    google.maps.event.addListenerOnce(
      this.clusterInfoWindow, "closeclick", () => {
        this.clearFuzzyBoxOverlay()
        this.noteInfoWindowClosed(this.clusterInfoWindow)
      }
    )
    google.maps.event.addListenerOnce(
      this.clusterInfoWindow, "domready", () => {
        this.wireClusterZoomLink(bounds)
      }
    )
  }

  wireClusterZoomLink(bounds) {
    const els = document.getElementsByClassName("map-popup-cluster-zoom")
    for (const el of els) {
      el.addEventListener("click", (event) => {
        event.preventDefault()
        this.map.fitBounds(bounds)
        if (this.clusterInfoWindow) this.clusterInfoWindow.close()
        this.clearFuzzyBoxOverlay()
      })
    }
  }

  // Union of all member boxes. For GPS obs the "box" collapses to a
  // point (set.north === set.south, etc.), so this degrades gracefully
  // to the GPS extent. For a Wilder-Ridge-style cluster where every
  // member uses its location bbox, the union equals that bbox.
  computeClusterOutlineBox(markers) {
    let n = null
    let s = null
    let e = null
    let w = null
    for (const marker of markers) {
      const b = marker.moData && marker.moData.box
      if (!b || b.n == null) continue
      if (n === null || b.n > n) n = b.n
      if (s === null || b.s < s) s = b.s
      if (e === null || b.e > e) e = b.e
      if (w === null || b.w < w) w = b.w
    }
    return (n !== null) ? { n, s, e, w } : null
  }

  // Skip drawing the overlay when the outline is the same size as the
  // cluster badge itself — an outline that's identical in area to the
  // marker is visual noise. Compares the outline's extents to the
  // MarkerClusterer-computed member bounds; if they match within a
  // small epsilon the outline adds no information.
  outlineLargerThanClusterBadge(outline, bounds) {
    if (!bounds) return true
    const ne = bounds.getNorthEast()
    const sw = bounds.getSouthWest()
    const EPS = 1e-4
    return Math.abs(outline.n - ne.lat()) > EPS ||
           Math.abs(outline.s - sw.lat()) > EPS ||
           Math.abs(outline.e - ne.lng()) > EPS ||
           Math.abs(outline.w - sw.lng()) > EPS
  }

  // Group cluster markers by species (text_name); sort by obs count
  // desc, then species name asc. Each list row links to the first
  // observation of that species.
  buildClusterPopupHtml(markers, canZoom, outlineBox) {
    const groups = this.groupClusterMarkersBySpecies(markers)
    const totalObs = markers.length
    const speciesCount = groups.length

    const parts = ['<div class="map-popup map-popup-cluster">']
    parts.push(
      '<div class="map-popup-cluster-header">' +
      '<div class="map-popup-cluster-title">' +
      `<strong>${totalObs} ${totalObs === 1 ? "observation" : "observations"}` +
      "</strong></div>" +
      '<div class="map-popup-cluster-subtitle">' +
      `${speciesCount} ${speciesCount === 1 ? "species" : "species"}` +
      "</div>" +
      this.buildClusterActionButtons(outlineBox) +
      "</div>"
    )
    parts.push('<ul class="map-popup-cluster-list">')
    for (const group of groups) {
      parts.push(this.renderClusterListItem(group))
    }
    parts.push("</ul>")
    if (canZoom) {
      parts.push(
        '<div class="map-popup-cluster-zoom-row">' +
        '<a href="#" class="map-popup-cluster-zoom">Click to zoom in</a>' +
        "</div>"
      )
    }
    parts.push("</div>")
    return parts.join("")
  }

  buildClusterActionButtons(outlineBox) {
    if (!outlineBox) return ""
    const showAll = this.clusterQueryUrl("/observations", outlineBox)
    const mapAll = this.clusterQueryUrl("/observations/map", outlineBox)
    const btn = "btn btn-default btn-xs map-popup-btn"
    return (
      '<div class="map-popup-cluster-actions">' +
      `<a href="${showAll}" class="${btn}">Show All</a>` +
      `<a href="${mapAll}" class="${btn}">Map All</a>` +
      "</div>"
    )
  }

  // Build a Show-All / Map-All URL by preserving the current page's
  // `q[...]` params (so user/name/etc. filters carry over) and
  // overriding `q[in_box][n/s/e/w]` with the cluster outline box.
  clusterQueryUrl(path, box) {
    const params = new URLSearchParams()
    const current = new URLSearchParams(window.location.search)
    const IN_BOX_PREFIX = "q[in_box]"
    for (const [key, value] of current.entries()) {
      if (key.startsWith("q[") && !key.startsWith(IN_BOX_PREFIX)) {
        params.append(key, value)
      }
    }
    params.append("q[in_box][north]", String(box.n))
    params.append("q[in_box][south]", String(box.s))
    params.append("q[in_box][east]", String(box.e))
    params.append("q[in_box][west]", String(box.w))
    return `${path}?${params.toString()}`
  }

  groupClusterMarkersBySpecies(markers) {
    const groups = new Map()
    for (const marker of markers) {
      const data = marker.moData || {}
      const name = data.cluster_name || "Unknown"
      let group = groups.get(name)
      if (!group) {
        group = { name, count: 0, url: null }
        groups.set(name, group)
      }
      group.count += 1
      if (!group.url && data.cluster_url) group.url = data.cluster_url
    }
    return Array.from(groups.values()).sort((a, b) => {
      if (b.count !== a.count) return b.count - a.count
      return a.name.localeCompare(b.name)
    })
  }

  renderClusterListItem(group) {
    const name = this.escapeHtml(group.name)
    const nameHtml = group.url
      ? `<a href="${group.url}" target="_blank" rel="noopener noreferrer">` +
        `<i>${name}</i></a>`
      : `<i>${name}</i>`
    return (
      "<li>" +
      `<span class="map-popup-cluster-name">${nameHtml}</span>` +
      `<strong class="map-popup-cluster-count">${group.count}</strong>` +
      "</li>"
    )
  }

  escapeHtml(text) {
    const tmp = document.createElement("div")
    tmp.textContent = text == null ? "" : String(text)
    return tmp.innerHTML
  }

  // Whether fitBounds on this cluster would actually reveal its members.
  // When every member shares a GPS point, bounds collapse to zero
  // extent and fitBounds pushes to max zoom with a single visible pin.
  clusterCanZoomFurther(bounds) {
    if (!bounds) return false
    const ne = bounds.getNorthEast()
    const sw = bounds.getSouthWest()
    const EPS = 1e-5
    return (ne.lat() - sw.lat()) > EPS || (ne.lng() - sw.lng()) > EPS
  }

  clusterRenderer() {
    return {
      render: ({ count, position, markers }) => {
        const color = this.aggregateClusterColor(markers)
        const border = this.aggregateClusterBorder(markers)
        return new google.maps.Marker({
          position,
          label: {
            text: String(count),
            color: "#fff",
            fontSize: "12px",
            fontWeight: "700"
          },
          icon: {
            path: google.maps.SymbolPath.CIRCLE,
            fillColor: color,
            fillOpacity: 0.9,
            strokeColor: this.borderStrokeColor(border),
            strokeOpacity: 1,
            strokeWeight: 1.5,
            // Scale up with digit count so the label always fits.
            scale: this.clusterMarkerScale(count)
          },
          title: `${count} observations`,
          zIndex: 1000 + markers.length
        })
      }
    }
  }

  clusterMarkerScale(count) {
    if (count < 10) return 14
    if (count < 100) return 18
    if (count < 1000) return 22
    return 26
  }

  //
  //  VIEWPORT REFETCH (#4159) — large obs sets are capped server-side;
  //  when the user pans/zooms into a smaller viewport we re-query with
  //  q[in_box] so the truncated obs become visible at the new scale.
  //

  scheduleViewportRefetch() {
    if (!this.clustering) return
    // An open popup (obs detail or cluster summary) means the user is
    // reading something — tearing markers out from under them is
    // jarring. Park the refetch until they dismiss the popup.
    if (this.activeInfoWindow) {
      this.refetchPending = true
      return
    }
    if (this.refetchTimer) clearTimeout(this.refetchTimer)
    this.refetchTimer = setTimeout(() => this.refetchForViewport(), 500)
  }

  refetchForViewport() {
    const bounds = this.map.getBounds()
    if (!bounds) return
    if (!this.viewportRefetchNeeded(bounds)) return
    if (this.refetchInFlight) this.refetchInFlight.abort()

    const controller = new AbortController()
    this.refetchInFlight = controller
    const url = this.buildRefetchUrl(bounds)

    fetch(url, {
      headers: { Accept: "application/json" },
      signal: controller.signal
    }).
      then((response) => response.json()).
      then((data) => this.applyRefetch(data, bounds)).
      catch((error) => {
        if (error.name !== "AbortError") {
          console.error("map refetch failed", error)
        }
      }).
      finally(() => {
        if (this.refetchInFlight === controller) this.refetchInFlight = null
      })
  }

  // Only re-hit the server when it can change the picture:
  // - last fetch was capped (smaller viewport might expose hidden obs
  //   or, on zoom-out, pull in obs from newly-visible area), or
  // - last fetch was bounded and the current viewport extends outside
  //   that box (we don't have data for the new area).
  viewportRefetchNeeded(currentBounds) {
    if (this.lastFetchedCapped) return true
    const last = this.lastFetchedBounds
    if (!last) return false // initial fetch was global and not capped

    return !last.contains(currentBounds.getNorthEast()) ||
           !last.contains(currentBounds.getSouthWest())
  }

  buildRefetchUrl(bounds) {
    const ne = bounds.getNorthEast()
    const sw = bounds.getSouthWest()
    const params = new URLSearchParams(window.location.search)
    for (const key of Array.from(params.keys())) {
      if (key.startsWith("q[in_box]")) params.delete(key)
    }
    params.set("q[in_box][north]", String(ne.lat()))
    params.set("q[in_box][south]", String(sw.lat()))
    params.set("q[in_box][east]", String(ne.lng()))
    params.set("q[in_box][west]", String(sw.lng()))
    const path = window.location.pathname.replace(/\.json$/, "")
    return `${path}.json?${params.toString()}`
  }

  applyRefetch(data, bounds) {
    if (!data || !data.collection) return
    // A popup opened mid-fetch. Drop this payload and mark the
    // refetch as pending; when the popup closes we'll pull fresh
    // data for the current viewport (which may have moved further
    // while the popup was open).
    if (this.activeInfoWindow) {
      this.refetchPending = true
      return
    }

    this.clearOverlays()
    this.collection = data.collection
    this.buildOverlays()
    this.updateCapBanner(data)

    this.lastFetchedBounds = bounds
    this.lastFetchedCapped = Boolean(data.capped)
  }

  clearOverlays() {
    if (this.markerClusterer) {
      this.markerClusterer.clearMarkers()
      this.markerClusterer = null
    }
    this.cluster_markers = []
    this.clearFuzzyBoxOverlay()
    if (this.clusterInfoWindow) {
      this.clusterInfoWindow.close()
      this.clusterInfoWindow = null
    }
    this.activeInfoWindow = null
    // The non-cluster markers/rectangles created by buildOverlays
    // attach directly to this.map; tracking them individually would
    // add a lot of bookkeeping, so we clear by iterating the overlay
    // records we do keep (clusterMarkers, fuzzy box). Anything else
    // will be GC'd when the new buildOverlays pass replaces the
    // dataset-driven references.
  }

  updateCapBanner(data) {
    const banner = document.getElementById("map_cap_banner")
    if (!banner) return
    if (data.capped) {
      banner.style.display = ""
      const loaded = Number(data.loaded).toLocaleString()
      const total = Number(data.total).toLocaleString()
      const template = (this.localized_text &&
                        this.localized_text.map_cap_banner) || ""
      banner.textContent = template.
        replace("__LOADED__", loaded).
        replace("__TOTAL__", total)
    } else {
      banner.style.display = "none"
    }
  }

  // Aggregate precision state across cluster members. Returns the same
  // values as MapSet#compute_border_style so the ring colors on the
  // cluster badge match the per-set markers.
  aggregateClusterBorder(markers) {
    let anyGps = false
    let anyNone = false
    for (const marker of markers) {
      const data = marker.moData
      if (!data) continue
      if (data.has_gps) anyGps = true
      else anyNone = true
      if (anyGps && anyNone) return "dashed"
    }
    if (anyGps && !anyNone) return "crisp"
    if (anyNone && !anyGps) return "none"
    return "crisp"
  }

  // Aggregate consensus-band color across every member of a cluster.
  // Mirrors Mappable::MapSet#compute_color on the Ruby side — we need
  // it in JS because cluster membership changes dynamically with
  // zoom and can't be baked in server-side (#4159).
  aggregateClusterColor(markers) {
    const bands = new Set()
    for (const marker of markers) {
      const data = marker.moData
      if (!data) continue
      const pct = data.vote_pct
      if (pct == null) continue
      if (pct <= 0) bands.add("disputed")
      else if (pct >= 80) bands.add("confirmed")
      else bands.add("tentative")
    }
    if (bands.size === 0) return "#3B79CC"  // location-only fallback
    if (bands.size > 1) return "#C69B71"    // mixed
    const band = bands.values().next().value
    return {
      confirmed: "#5CB85C",
      tentative: "#F0AD4E",
      disputed: "#D9534F"
    }[band]
  }

  isPoint(set) {
    return (set.north === set.south) && (set.east === set.west)
  }

  hasBoxExtents(set) {
    return set && set.north !== set.south && set.east !== set.west
  }

  //
  //  MARKERS - used in info mapType (for certain sets)
  //            and in observation mapType (`set` can just be a latLng object)
  //

  // There may not be a marker yet.
  placeMarker(location) {
    this.verbose("map:placeMarker")
    if (!this.marker) {
      this.drawMarker(location)
    } else {
      this.verbose("map:marker.setPosition")
      this.marker.setPosition(location)
      this.map.panTo(location)
    }
    this.marker.setVisible(true)
  }

  drawMarker(set) {
    this.verbose("map:drawMarker")
    // Per-marker color and border style come from the server
    // (Mappable::MapSet — issues #4131, #4159). Falls back to the
    // controller default for editable markers / legacy callers.
    const color = (set && set.color) || this.marker_color
    const border = (set && set.border_style) || "crisp"
    const markerOptions = {
      position: { lat: set.lat, lng: set.lng },
      // In clustering mode, don't attach to the map — the
      // MarkerClusterer decides visibility based on current zoom
      // (#4159).
      map: this.clustering ? null : this.map,
      draggable: this.editable,
      icon: this.colored_circle_icon(color, border),
      zoomOnClick: false
    }

    if (!this.editable) {
      markerOptions.title = set.title
    }
    const marker = new google.maps.Marker(markerOptions)
    this.marker = marker
    // Metadata the cluster renderer / popup uses. `vote_pct` and
    // `has_gps` drive cluster color / border aggregation.
    // `cluster_name` + `cluster_url` let the popup group by species.
    // `box` is the set's geographic footprint (a point for GPS obs,
    // the location bbox for fuzzy obs) so the popup can draw an
    // outline overlay covering all members (#4159).
    marker.moData = {
      vote_pct: this.votePctFromSet(set),
      has_gps: border !== "none",
      cluster_name: set ? set.cluster_name : null,
      cluster_url: set ? set.cluster_url : null,
      box: set
        ? { n: set.north, s: set.south, e: set.east, w: set.west }
        : null
    }

    if (!this.editable && set != null) {
      this.giveMarkerInfoWindow(marker, set)
      // Fuzzy single-obs dots (no GPS) show the location's bounding
      // box as an overlay while their popup is open (#4159).
      if (border === "none" && this.hasBoxExtents(set)) {
        this.attachFuzzyBoxOverlay(marker, set)
      }
      if (this.clustering) {
        this.cluster_markers.push({ marker, set })
      }
    } else {
      this.getElevations([set], "point")
      this.makeMarkerEditable(marker)
    }
  }

  // Reverse-engineer the consensus band color shipped by
  // MapSet#compute_color. Singleton MapSets (clustering mode) carry
  // just the color hex; the band is enough for cluster-color math.
  votePctFromSet(set) {
    if (!set || !set.color) return null
    const color = set.color
    if (color === "#5CB85C") return 90  // confirmed
    if (color === "#F0AD4E") return 40  // tentative
    if (color === "#D9534F") return -1  // disputed
    return null // mixed / location-only
  }

  // Only for single markers: listeners for dragging the marker
  makeMarkerEditable(marker) {
    if (!marker) return

    this.verbose("map:makeMarkerEditable")
    // clearTimeout(this.marker_edit_buffer)
    // this.marker_edit_buffer = setTimeout(() => {
    const events = ["position_changed", "dragend"]
    events.forEach((eventName) => {
      marker.addListener(eventName, () => {
        const newPosition = marker.getPosition()?.toJSON() // latlng object
        // if (this.hasNorthInputTarget) {
        //   const bounds = this.boundsOfPoint(newPosition)
        //   this.updateBoundsInputs(bounds)
        // } else
        if (this.hasLatInputTarget) {
          this.updateLatLngInputs(newPosition) // dispatches pointChanged
          // Moving the marker means we're no longer on the image lat/lng
          this.dispatch("reenableBtns")
        }
        // this.sampleElevationCenterOf(newPosition)
        this.getElevations([newPosition], "point")
        this.map.panTo(newPosition)
      })
    })
    // Give the current value to the inputs
    const newPosition = marker.getPosition()?.toJSON()
    if (this.hasLatInputTarget && !this.latInputTarget.value) {
      this.updateLatLngInputs(newPosition)
    }

    // this.marker = marker
    // }, 1000)
  }

  // For point markers: make a clickable InfoWindow. In clustering
  // mode the caption HTML is not shipped in the bulk payload (too
  // expensive at 10K obs) — we lazy-fetch it from the server on
  // click and cache on the set so subsequent clicks are instant
  // (#4159).
  giveMarkerInfoWindow(marker, set) {
    this.verbose("map:giveMarkerInfoWindow")
    const info_window = new google.maps.InfoWindow({
      content: set.caption ||
               '<div class="map-popup map-popup-loading">Loading…</div>',
      position: { lat: set.lat, lng: set.lng },
      maxWidth: 280
    })
    marker.infoWindow = info_window

    google.maps.event.addListener(marker, "click", () => {
      info_window.open({ anchor: marker, map: this.map })
      this.noteInfoWindowOpened(info_window)
      if (!set.caption && this.clustering) {
        this.loadMarkerPopup(info_window, set)
      }
    })
    google.maps.event.addListener(info_window, "closeclick", () => {
      this.noteInfoWindowClosed(info_window)
    })
  }

  noteInfoWindowOpened(info_window) {
    this.activeInfoWindow = info_window
  }

  noteInfoWindowClosed(info_window) {
    if (this.activeInfoWindow === info_window) {
      this.activeInfoWindow = null
      this.flushPendingRefetch()
    }
  }

  flushPendingRefetch() {
    if (!this.refetchPending) return
    this.refetchPending = false
    this.scheduleViewportRefetch()
  }

  loadMarkerPopup(info_window, set) {
    const url = this.markerPopupUrl(set)
    if (!url) {
      console.warn("map popup: no URL derived from set", set)
      info_window.setContent('<div class="map-popup">No details</div>')
      return
    }
    fetch(url, {
      headers: { Accept: "application/json" },
      credentials: "same-origin"
    }).
      then(async (response) => {
        if (!response.ok) {
          const body = await response.text()
          throw new Error(
            `map popup HTTP ${response.status} ${url}\n${body.slice(0, 200)}`
          )
        }
        return response.json()
      }).
      then((data) => {
        if (!data || data.html == null) {
          throw new Error(`map popup: malformed response ${JSON.stringify(data)}`)
        }
        set.caption = data.html
        info_window.setContent(data.html)
      }).
      catch((error) => {
        console.error(error)
        info_window.setContent(
          '<div class="map-popup">Error loading details</div>'
        )
      })
  }

  // Clustered singleton sets carry `cluster_url` = /observations/:id.
  // The popup lives at /observations/:id/map_popup.
  markerPopupUrl(set) {
    if (!set || !set.cluster_url) return null
    const match = set.cluster_url.match(/^(\/observations\/\d+)(\?|$)/)
    if (!match) return null
    const base = match[1]
    const query = set.cluster_url.slice(match[1].length) // preserves ?q=...
    return `${base}/map_popup${query}`
  }

  //
  //  RECTANGLES For info mapType, need to pass the whole set.
  //             For location mapType, the `set` can just be bounds.
  //             For observation mapType, the rectangle is display-only.
  //

  placeRectangle(extents) {
    this.verbose("map:placeRectangle()")
    this.verbose(extents)

    if (!extents) return false

    // Fit bounds first, then draw/update rectangle after zoom completes
    this.map.fitBounds(extents)

    // Wait for the map to finish zooming before drawing/updating rectangle
    google.maps.event.addListenerOnce(this.map, 'bounds_changed', () => {
      if (!this.rectangle) {
        this.drawRectangle(extents)
      } else {
        this.rectangle.setBounds(extents)
      }
      const _types = ["location", "hybrid"]
      if (_types.includes(this.map_type)) { this.rectangle.setEditable(true) }
      this.rectangle.setVisible(true)
    })
  }

  drawRectangle(set) {
    this.verbose("map:drawRectangle()")
    this.verbose(set)
    const bounds = this.boundsOf(set)
    if (!bounds) return false

    // Per-box color from the server: the aggregated consensus color
    // (#4159), or the location-only blue if no observations were in
    // the set. Always honor whatever the server computed.
    const color = (set && set.color) || this.marker_color
    const border = (set && set.border_style) || "crisp"

    // Info maps: every multi-obs set renders as a fixed-size square
    // marker at the box's center (#4159). The underlying extents
    // surface as an outline overlay when the user clicks a
    // location-only marker and the box is visibly larger than the
    // marker footprint.
    if (this.map_type === "info" && !this.editable) {
      this.drawBoxAsSquareMarker(set, color, border)
      return
    }

    const editable = this.editable && this.map_type !== "observation",
      rectangleOptions = {
        strokeColor: color,
        strokeOpacity: 1,
        strokeWeight: 3,
        fillColor: color,
        fillOpacity: 0,
        map: this.map,
        bounds: bounds,
        clickable: false,
        draggable: false,
        editable: editable
      },
      rectangle = new google.maps.Rectangle(rectangleOptions)

    if (this.map_type === "observation") {
      // that's it. obs rectangles for MO locations are not clickable
      this.rectangle = rectangle
    } else {
      this.rectangle = rectangle
      this.makeRectangleEditable()
    }
  }

  // Location-only sets on info maps: draw the box outline at its true
  // extents with no center marker. Opens the caption in an info window
  // on click so clustered location maps keep their per-box popup.
  drawLocationOutline(set) {
    this.verbose("map:drawLocationOutline")
    const bounds = this.boundsOf(set)
    if (!bounds) return false

    const color = (set && set.color) || this.marker_color
    const rectangle = new google.maps.Rectangle({
      strokeColor: color,
      strokeOpacity: 1,
      strokeWeight: 2,
      fillColor: color,
      fillOpacity: 0.25,
      map: this.map,
      bounds: bounds,
      clickable: true,
      draggable: false,
      editable: false
    })
    if (set && set.caption) {
      const info_window = new google.maps.InfoWindow({
        content: set.caption,
        position: bounds
          ? { lat: (bounds.north + bounds.south) / 2,
              lng: (bounds.east + bounds.west) / 2 }
          : rectangle.getBounds().getCenter()
      })
      google.maps.event.addListener(rectangle, "click", () => {
        info_window.open(this.map, rectangle)
      })
    }
  }

  // Pixel threshold below which a rectangle collapses into something
  // indistinguishable from a marker. Swap it for a square marker only
  // when BOTH dimensions fall below the threshold — otherwise a thin
  // tall strip or wide flat strip is still a meaningful shape and should
  // render as the real rectangle.
  MIN_RECT_PIXELS = 15

  // `bounds` here is the plain {north, south, east, west} object
  // returned by this.boundsOf(set), NOT a google.maps.LatLngBounds.
  rectangleTooSmall(bounds) {
    if (!bounds) return false
    const projection = this.map.getProjection()
    if (!projection) return false
    const zoom = this.map.getZoom()
    if (zoom === undefined) return false
    const scale = Math.pow(2, zoom)
    const ne = projection.fromLatLngToPoint(
      new google.maps.LatLng(bounds.north, bounds.east)
    )
    const sw = projection.fromLatLngToPoint(
      new google.maps.LatLng(bounds.south, bounds.west)
    )
    const widthPx = Math.abs(ne.x - sw.x) * scale
    const heightPx = Math.abs(sw.y - ne.y) * scale
    return widthPx < this.MIN_RECT_PIXELS && heightPx < this.MIN_RECT_PIXELS
  }

  // Draws a square marker at the center of a box that's too small to
  // render as a rectangle. Visually distinct from single-observation
  // circle markers (square vs circle signals "group").
  drawBoxAsSquareMarker(set, color, border = "crisp") {
    const marker = new google.maps.Marker({
      position: { lat: set.lat, lng: set.lng },
      map: this.map,
      title: set.title,
      icon: this.colored_square_icon(color, border),
      zoomOnClick: false
    })
    this.giveMarkerInfoWindow(marker, set)
    if (border === "none" && this.hasBoxExtents(set)) {
      this.attachFuzzyBoxOverlay(marker, set)
    }
  }

  // Square marker used for every multi-obs set on info maps (#4159).
  // Same fill/ring scheme as the single-obs dot — see
  // colored_circle_icon.
  colored_square_icon(color, border = "crisp") {
    return {
      path: "M -6 -6 L 6 -6 L 6 6 L -6 6 z",
      fillColor: color,
      fillOpacity: 1,
      strokeColor: this.borderStrokeColor(border),
      strokeOpacity: 1,
      strokeWeight: 1.5,
      scale: 1
    }
  }

  // Ring color by precision band (#4159).
  borderStrokeColor(border) {
    if (border === "none") return "#ffffff"
    if (border === "dashed") return "#888888"
    return "#333333"
  }

  // Add listeners to the rectangle for dragging and resizing (possibly also
  // listen to "dragstart", "drag" ? not necessary). If we're just switching to
  // location mode, we need a buffer or it's too fast
  makeRectangleEditable() {
    this.verbose("map:makeRectangleEditable")
    // clearTimeout(this.rectangle_buffer)
    // this.rectangle_buffer = setTimeout(() => {
    const events = ["bounds_changed", "dragend"]
    events.forEach((eventName) => {
      this.rectangle.addListener(eventName, () => {
        const newBounds = this.rectangle.getBounds()?.toJSON() // nsew object
        // this.verbose({ newBounds })
        this.updateBoundsInputs(newBounds)
        this.getElevations(this.sampleElevationPointsOf(newBounds), "rectangle")
        this.map.fitBounds(newBounds)
      })
    })
    // }, 1000)
  }

  //
  //  FORM INPUTS : Functions for altering the map from form inputs
  //

  // Action called from the location form n_s_e_w_hi_lo inputs onChange
  // and from observation form lat_lng inputs (debounces inputs)
  bufferInputs() {
    if (["location"].includes(this.map_type)) {
      if (this.opened) {
        this.clearMarkerDrawBuffer()
        this.marker_draw_buffer =
          setTimeout(() => this.calculateRectangle(), 1000)
      }
    }
    if (["observation", "hybrid"].includes(this.map_type)) {
      // this.verbose("map:pointChanged")
      // If they just cleared the inputs, swap back to a location autocompleter
      const center = this.validateLatLngInputs(false)

      // Always send point changed - even when clearing lat/lng (center is null)
      // This triggers swap back to 'location' type when lat/lng are cleared
      this.sendPointChanged(center || { lat: null, lng: null })

      if (this.latInputTarget.value === "" ||
        this.lngInputTarget.value === "" && this.marker) {
        this.marker.setVisible(false) // delete the marker immediately
      } else {
        if (this.opened) {
          this.clearMarkerDrawBuffer()
          this.marker_draw_buffer =
            setTimeout(() => this.calculateMarker(), 1000)
        }
      }
    }
  }

  clearMarkerDrawBuffer() {
    if (this.marker_draw_buffer) {
      clearTimeout(this.marker_draw_buffer)
      this.marker_draw_buffer = 0
    }
  }

  // Action to map an MO location, or geocode a location from a place name.
  // Can be called directly from a button, so check for input values.
  // Now fired when locationIdTarget changes, including when it's zero
  showBox() {
    if (!(this.opened && this.hasPlaceInputTarget &&
      this.placeInputTarget.value))
      return false

    // Forms where location is optional: stay mum unless we're in create mode
    if (this.hasAutocompleterTarget &&
      !this.autocompleterTarget.classList.contains("create"))
      return false

    this.verbose("map:showBox")
    // buffer inputs if they're still typing
    clearTimeout(this.marker_draw_buffer)
    this.marker_draw_buffer = setTimeout(() => this.checkForBox(), 1000)
  }

  // Check what kind of input we have and call the appropriate function
  checkForBox() {
    this.verbose("map:checkForBox")
    let id
    if (this.hasLocationIdTarget && (id = this.locationIdTarget.value)) {
      this.mapLocationIdData()
    } else if (["location", "hybrid"].includes(this.map_type)) {
      // Only geocode lat/lng if we have no location_id and not ignoring place
      // ...and only geolocate placeName if we have no lat/lng
      // Note: is this the right logic ?????????????
      if (this.ignorePlaceInput !== false) {
        this.tryToGeocode() // multiple possible results
      } else {
        this.tryToGeolocate()
      }
    }
    if (this.rectangle) this.rectangle.setVisible(true)
  }

  // The locationIdTarget should have the bounds in its dataset
  mapLocationIdData() {
    if (!this.hasLocationIdTarget || !this.locationIdTarget.dataset.north)
      return false

    this.verbose("map:mapLocationIdData")
    const north = parseFloat(this.locationIdTarget.dataset.north)
    const south = parseFloat(this.locationIdTarget.dataset.south)
    const east = parseFloat(this.locationIdTarget.dataset.east)
    const west = parseFloat(this.locationIdTarget.dataset.west)

    // Validate all bounds are valid numbers before using
    if (isNaN(north) || isNaN(south) || isNaN(east) || isNaN(west))
      return false

    const bounds = { north, south, east, west }
    this.placeClosestRectangle(bounds, null)
  }

  //
  //  LOCATION FORM
  //

  // Sends user-entered NSEW to the rectangle. Buffered by the above
  calculateRectangle() {
    const north = parseFloat(this.northInputTarget.value)
    const south = parseFloat(this.southInputTarget.value)
    const east = parseFloat(this.eastInputTarget.value)
    const west = parseFloat(this.westInputTarget.value)

    if (isNaN(north) || isNaN(south) || isNaN(east) || isNaN(west)) return false

    this.verbose("map:calculateRectangle")
    const bounds = { north: north, south: south, east: east, west: west }

    // Fit bounds first, then update rectangle after zoom completes
    this.map.fitBounds(bounds)
    google.maps.event.addListenerOnce(this.map, 'bounds_changed', () => {
      if (this.rectangle) {
        this.rectangle.setBounds(bounds)
      }
    })
  }

  // Infers a rectangle from the google place, if found. (could be point/bounds)
  placeClosestRectangle(viewport, extents) {
    this.verbose("map:placeClosestRectangle")
    // Prefer extents for rectangle, fallback to viewport
    let bounds = extents || viewport
    if (bounds != undefined && bounds?.north) {
      this.placeRectangle(bounds)
    }
    // else if (center) {
    // this.placeMarker(center) // if marker is ok for this map
    // this.placeRectangle(this.boundsOfPoint(center))
    // }
  }

  //
  //  OBSERVATION FORM
  //

  // called by toggleMap
  checkForMarker() {
    this.verbose("map:checkForMarker")
    let center
    if (center = this.validateLatLngInputs(false)) {
      this.calculateMarker({ detail: { request_params: center } })
    }
  }

  // Action called via toggleMap, after bufferInputs from lat/lng inputs, to
  // update map marker, and directly by form-exif controller emitting the
  // pointChanged event. Checks if lat & lng fields already populated on load if
  // so, drops a pin on that location and center. Otherwise, checks if place
  // input has been prepopulated and uses that to focus map and drop a marker.
  calculateMarker(event) {
    if (this.map == undefined || !this.hasLatInputTarget ||
      this.latInputTarget.value === '' || this.lngInputTarget.value === '')
      return false

    this.verbose("map:calculateMarker")
    let location
    if (event?.detail?.request_params) {
      location = event.detail.request_params
    } else {
      location = this.validateLatLngInputs(true)
    }
    if (location) {
      this.placeMarker(location)
      this.map.setCenter(location)
      this.map.setZoom(9)
    }
  }

  // Action called by the "Open Map" button only.
  // open/close handled by BS collapse
  toggleMap() {
    this.verbose("map:toggleMap")
    if (this.opened) {
      this.closeMap()
    } else {
      this.openMap()
    }
  }

  closeMap() {
    this.verbose("map:closeMap")
    this.opened = false
    this.controlWrapTarget.classList.remove("map-open")
  }

  openMap() {
    this.verbose("map:openMap")
    this.opened = true
    this.controlWrapTarget.classList.add("map-open")

    if (this.map == undefined) {
      this.drawMap()
      this.makeMapClickable()
    } else if (this.mapBounds) {
      this.map.fitBounds(this.mapBounds)
    }

    setTimeout(() => {
      this.checkForMarker()
      this.checkForBox() // regardless if point
    }, 500) // wait for map to open
  }

  makeMapClickable() {
    this.verbose("map:makeMapClickable")
    google.maps.event.addListener(this.map, 'click', (e) => {
      // this.map.addListener('click', (e) => {
      const location = e.latLng.toJSON()
      this.placeMarker(location)
      this.marker.setVisible(true)
      this.map.panTo(location)
      // if (zoom < 15) { this.map.setZoom(zoom + 2) } // for incremental zoom
      this.updateFields(null, null, location)
    });
  }

  // Action called from the "Clear Map" button
  clearMap() {
    this.verbose("map:clearMap")
    const inputTargets = [
      this.placeInputTarget, this.northInputTarget, this.southInputTarget,
      this.eastInputTarget, this.westInputTarget, this.highInputTarget,
      this.lowInputTarget
    ]
    if (this.hasLatInputTarget) { inputTargets.push(this.latInputTarget) }
    if (this.hasLngInputTarget) { inputTargets.push(this.lngInputTarget) }
    if (this.hasAltInputTarget) { inputTargets.push(this.altInputTarget) }

    inputTargets.forEach((element) => { element.value = '' })
    this.ignorePlaceInput = false // turn string geolocation back on

    this.clearMarker()
    this.clearRectangle()
    this.dispatch("reenableBtns")
    this.sendPointChanged({ lat: null, lng: null })
  }

  clearMarker() {
    if (!this.marker) return false

    this.verbose("map:clearMarker")
    this.marker.setMap(null)
    this.marker = null
  }

  clearRectangle() {
    if (!this.rectangle) return false

    this.verbose("map:clearRectangle")
    this.rectangle.setVisible(false)
    this.rectangle.setMap(null)
    this.rectangle = null
    return true
  }

  //
  //  COORDINATES
  //

  // Every MapSet should have properties north, south, east, west (plus corners)
  // Alternatively, just send a simple object (e.g. `extents`) with `nsew` props
  // Returns valid bounds object or null if any value is missing/invalid
  boundsOf(set) {
    if (!set?.north) return null

    const bounds = {
      north: set.north, south: set.south, east: set.east, west: set.west
    }

    // Validate all bounds are valid numbers
    if (isNaN(bounds.north) || isNaN(bounds.south) ||
        isNaN(bounds.east) || isNaN(bounds.west)) {
      console.warn("boundsOf: invalid bounds", bounds, "from set", set)
      return null
    }

    return bounds
  }

  // mapBounds may fill the extents of a rectangle or a point in the inputs.
  // extentsForInput(extents, center) {
  //   let bounds
  //   if (extents) {
  //     bounds = this.boundsOf(extents)
  //   } else if (center) {
  //     bounds = this.boundsOfPoint(center)
  //   }
  //   return bounds
  // }

  // When you need to turn a point into some "bounds", e.g. to fill inputs
  // boundsOfPoint(center) {
  //   const bounds = {
  //     north: center.lat,
  //     south: center.lat,
  //     east: center.lng,
  //     west: center.lng
  //   }
  //   return bounds
  // }

  // Each corner (e.g. north_east) is an array [lat, lng]
  cornersOf(set) {
    const corners = {
      ne: set.north_east,
      se: set.south_east,
      sw: set.south_west,
      nw: set.north_west
    }
    return corners
  }

  //
  //  COORDINATES - ELEVATION
  //

  sampleElevationPoints() {
    let points
    if (this.marker) {
      const position = this.marker.getPosition().toJSON()
      points = [position] // this.sampleElevationCenterOf(position)
    } else if (this.rectangle) {
      const bounds = this.rectangle.getBounds().toJSON()
      points = this.sampleElevationPointsOf(bounds)
    }
    return points
  }

  // ------------------------------- DEBUGGING ------------------------------

  // helpDebug() {
  //   debugger
  // }

  verbose(str) {
    // console.log(str);
    // document.getElementById("log").
    //   insertAdjacentText("beforeend", str + "<br/>");
  }

  // Colored circle icon for google.maps.Marker. Fill is always the
  // consensus color; the ring color encodes precision (#4159):
  //   crisp  → dark ring   (precise GPS)
  //   none   → white ring  (fuzzy / location-only)
  //   dashed → gray ring   (mixed; only applies to multi-obs squares
  //                         in practice, but harmless on dots too)
  colored_circle_icon(color, border = "crisp") {
    return {
      path: google.maps.SymbolPath.CIRCLE,
      fillColor: color,
      fillOpacity: 1,
      strokeColor: this.borderStrokeColor(border),
      strokeOpacity: 1,
      strokeWeight: 1.5,
      scale: 8
    }
  }

  // When a location-only marker's popup is opened, overlay the
  // region's bounding box as an outline so the uncertainty area is
  // visible. Skipped when the extents don't render visibly larger
  // than the marker itself (would just be a same-sized square on top
  // of the marker). Google auto-closes the previously open
  // InfoWindow when another opens but doesn't emit an event on the
  // old one — so track a single controller-level overlay and clear
  // it before adding a new one.
  attachFuzzyBoxOverlay(marker, set) {
    marker.addListener("click", () => {
      this.clearFuzzyBoxOverlay()
      const bounds = this.boundsOf(set)
      if (!bounds || this.rectangleTooSmall(bounds)) return
      this.fuzzyBoxOverlay = new google.maps.Rectangle({
        strokeColor: set.color,
        strokeOpacity: 1,
        strokeWeight: 2,
        fillColor: set.color,
        fillOpacity: 0.25,
        bounds: bounds,
        clickable: false,
        map: this.map
      })
    })
    if (marker.infoWindow) {
      marker.infoWindow.addListener("closeclick",
                                    () => this.clearFuzzyBoxOverlay())
    }
  }

  clearFuzzyBoxOverlay() {
    if (!this.fuzzyBoxOverlay) return
    this.fuzzyBoxOverlay.setMap(null)
    this.fuzzyBoxOverlay = null
  }
}
