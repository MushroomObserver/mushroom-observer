import { Controller } from "@hotwired/stimulus"
import ExifReader from 'exifreader';

const internalConfig = {
  // Make some of these targets for the controller
  content: document.getElementById('content'),
  localized_text: {
    months: "January, February, March, April, May, June, July, August, September, October, November, December",
  }
}

// The "form-exif" controller works together with the "form-images" controller
// to read the EXIF image data from an uploaded image during record creation UX.
// This controller needs to be on the whole form, to enable the large drop area
// (formerly the "observation_images" section of the form).
export default class extends Controller {
  static targets = ["carousel", "item", "useExifBtn",
    "collapseFields", "collapseCheck"]
  static outlets = ["autocompleter", "map"]

  connect() {
    this.element.dataset.formExif = "connected";

    Object.assign(this, internalConfig);
    Object.assign(this.localized_text,
      JSON.parse(this.element.dataset.localization));
  }

  // Stimulus "target callback" on carousel item added.
  // When Turbo prepends the carousel item to the page, we need to
  // populate the form with a few details about the file from the EXIF data
  itemTargetConnected(itemElement) {
    // console.log("itemTargetConnected")
    // console.log(itemElement);
    // Skip if already initialized to avoid re-extracting EXIF data
    if (itemElement.dataset.initialized == "true") return;

    // For saved "good" images, the server has already extracted EXIF data
    // from the original files and passed it via camera_info props.
    // We only need to extract EXIF in the browser for "upload" images.
    if (itemElement.dataset.imageStatus == "good") {
      itemElement.dataset.initialized = "true";
      return;
    }

    // Initialize geocode for uploads
    itemElement.dataset.geocode = "";

    // extract the EXIF data (async) and populate the item and element
    this.getExifData(itemElement);
  }

  // maybe stimulus action on image?
  // extracts the exif data async;
  getExifData(itemElement) {
    const _image = itemElement.querySelector('.carousel-image');

    const loadExifData = async () => {
      try {
        const _exif_data = await ExifReader.load(_image.src);
        this.populateExifData(itemElement, _exif_data);
      } catch (error) {
        console.log("Could not load EXIF data:", error);
      }
    };

    // If image is already loaded (e.g., from cache or saved image),
    // extract EXIF data immediately
    if (_image.complete && _image.naturalHeight !== 0) {
      loadExifData();
    } else {
      // Otherwise, wait for image to load
      _image.onload = loadExifData;
    }
  }

  // Now that we've read the data from the loaded file, populate carousel-item
  populateExifData(itemElement, exif_data) {
    itemElement.dataset.initialized = "true"

    this.populateExifGPS(itemElement, exif_data);
    this.populateExifDate(itemElement, exif_data);

    // emit an event that form-images listens for, to set item.exif_populated
    this.dispatch("populated", { detail: { target: itemElement } });

    // If this is the first one, transfer the exif data to the obs fields
    // and set a flag so we don't do it again. Here because it's async.
    if (this.element.dataset?.exifUsed !== "true" &&
      itemElement.dataset?.geocode !== "") {
      this.transferExifToObsFields(itemElement);
      this.element.dataset.exifUsed = "true";
    }
  }

  populateExifGPS(itemElement, exif_data) {
    const _exif_gps = itemElement.querySelector(".exif_gps"),
      _exif_no_gps = itemElement.querySelector(".exif_no_gps"),
      _exif_lat = itemElement.querySelector(".exif_lat"),
      _exif_lng = itemElement.querySelector(".exif_lng"),
      _exif_alt = itemElement.querySelector(".exif_alt"),
      _exif_lat_wrapper = itemElement.querySelector(".exif_lat_wrapper"),
      _exif_lng_wrapper = itemElement.querySelector(".exif_lng_wrapper"),
      _exif_alt_wrapper = itemElement.querySelector(".exif_alt_wrapper"),
      _use_exif_button = itemElement.querySelector('.use_exif_btn');

    // Geocode Logic
    // check if there is geodata on the image
    if (exif_data.GPSLatitude && exif_data.GPSLatitude.description &&
      exif_data.GPSLongitude && exif_data.GPSLongitude.description) {
      const latLngAlt = this.getLatLngEXIF(exif_data),
        { lat, lng, alt } = latLngAlt;

      // Set item's data-geocode attribute so we can have a record
      itemElement.dataset.geocode = JSON.stringify(latLngAlt);

      // These are spans, not inputs — set innerText, not value
      _exif_lat.innerText = lat == null ? lat : lat.toFixed(4);
      _exif_lng.innerText = lng == null ? lng : lng.toFixed(4);
      _exif_alt.innerText = alt == null ? alt : alt.toFixed(0);

      // Show the wrapper spans by removing d-none class
      if (_exif_lat_wrapper && lat != null) {
        _exif_lat_wrapper.classList.remove('d-none');
      }
      if (_exif_lng_wrapper && lng != null) {
        _exif_lng_wrapper.classList.remove('d-none');
      }
      if (_exif_alt_wrapper && alt != null) {
        _exif_alt_wrapper.classList.remove('d-none');
      }

      _use_exif_button.classList.remove('d-none');
    } else {
      // Show the "no GPS" message
      _exif_gps.classList.add("d-none");
      _exif_no_gps.classList.remove("d-none");
    }
  }

  getLatLngEXIF(exifObject) {
    let lat = exifObject.GPSLatitude.description;
    let lng = exifObject.GPSLongitude.description;

    const alt = exifObject.GPSAltitude ? ((exifObject.GPSAltitude.value[0]
      / exifObject.GPSAltitude.value[1]) || null) : null;

    // make sure you don't end up on the wrong side of the world
    lng = exifObject.GPSLongitudeRef.value[0] == "W" ? lng * -1 : lng;
    lat = exifObject.GPSLatitudeRef.value[0] == "S" ? lat * -1 : lat;

    lat = lat || null;
    lng = lng || null;
    return { lat, lng, alt };
  }

  populateExifDate(itemElement, exif_data) {
    const _exif_date = itemElement.querySelector(".exif_date"),
      _use_exif_button = itemElement.querySelector('.use_exif_btn');
    _exif_date.dataset.found = 'false';

    const _exifSimpleDate = this.parseExifDate(exif_data);
    if (_exifSimpleDate) {
      this.imageDate(itemElement, _exifSimpleDate);

      // shows the exif date by the photo
      itemElement.dataset.exif_date = JSON.stringify(_exifSimpleDate);
      _exif_date.innerText = this.simpleDateAsString(_exifSimpleDate);
      _exif_date.dataset.found = "true";
      _use_exif_button.classList.remove('d-none');
    }
    // no date was found in EXIF data
    else {
      // Use observation date
      this.imageDate(itemElement, this.observationDate());
    }
  }

  // EXIF date parsing logic
  // Confusingly, some cameras seem to incorrectly implement the EXIF standard,
  // either storing other datetime formats or misusing field name conventions.
  // So we can't be too sure what we'll get.
  // For example, note the difference in date/time separators for EXIF and ISO:
  //   {description: "2025:03:09 16:46:41.560", correct for EXIF
  //    value: "2025-03-09T16:46:41.560"}, ISO, incorrect for EXIF
  parseExifDate(exif_data) {
    const _known_field_names = ["DateTimeDigitized", "DateTimeOriginal"];
    const _fieldName = _known_field_names.find((fieldName) =>
      exif_data?.hasOwnProperty(fieldName) &&
      exif_data[fieldName].hasOwnProperty("description")
    );
    if (!_fieldName) {
      console.log(
        "Couldn't recognize a dateTime field in the EXIF data: " +
        JSON.stringify(exif_data)
      );
      return false;
    }
    const _dateTime = exif_data[_fieldName]["description"]
    if (!_dateTime) {
      console.log(
        "Couldn't find a recognizable EXIF date field: " +
        JSON.stringify(exif_data)
      );
      return false;
    }
    const _separator = _dateTime.includes(" ") ? " " : "T";
    if (!_separator) {
      console.log(
        "Couldn't recognize a date/time separator in the EXIF date field: " +
        _dateTime
      );
      return false;
    }
    const _date = _dateTime.substring(_separator, 10),
      _date_separator = _date.includes(":") ? ":" : "-";
    if (!_date_separator) {
      console.log(
        "Didn't recognize the date digit separator in the EXIF date field: " +
        _dateTime
      );
      return false;
    }
    const _date_taken_array = _date.split(_date_separator).reverse();
    if (_date_taken_array.length !== 3) {
      console.log(
        "The EXIF date field: doesn't seem to have a year, month and day: " +
        _dateTime
      );
      return false
    }
    return this.SimpleDate(..._date_taken_array);
  }

  // Click callback so .exif_date will set the image date if clicked
  exifToImageDate(event) {
    const _itemElement = event.target.closest(".item"),
      _exifSimpleDate = JSON.parse(_itemElement.dataset.exif_date);

    this.imageDate(_itemElement, _exifSimpleDate);
  }

  // Click callback for button.
  transferExifToObs(event) {
    const _itemElement = event.target.closest('.item');

    this.transferExifToObsFields(_itemElement);
  }

  // Transfers exif date and geocode directly from carousel item dataset to obs.
  // Pass an element to use from button or itemTargetConnected callback.
  // Also disables the "transfer" button for this element
  transferExifToObsFields(element) {
    const _exif_data = element.dataset,
      _obs_lat = document.getElementById('observation_lat'),
      _obs_lng = document.getElementById('observation_lng'),
      _obs_alt = document.getElementById('observation_alt');

    if (_exif_data.geocode && _exif_data.geocode !== "") {
      const latLngAlt = JSON.parse(_exif_data.geocode),
        { lat, lng, alt } = latLngAlt;

      _obs_lat.value = lat == null ? lat : lat.toFixed(4);
      _obs_lng.value = lng == null ? lng : lng.toFixed(4);
      _obs_alt.value = alt == null ? alt : alt.toFixed(0);

      // should trigger change to update the autocompleter and the map
      if (this.hasAutocompleterOutlet) {
        this.autocompleterOutlet.swap({
          detail: { type: "location_containing", request_params: { lat, lng } }
        });
      }
      if (this.hasMapOutlet) {
        this.mapOutlet.calculateMarker(
          { detail: { request_params: { lat, lng } } }
        );
      }
    }
    if (_exif_data.exif_date) {
      const _exifSimpleDate = JSON.parse(_exif_data.exif_date);
      this.observationDate(_exifSimpleDate);
    }
    // disables the button, even when called programmatically
    this.selectExifButton(element);
    // show the geolocation fields
    this.showFields();
  }

  // show the geolocation fields
  showFields() {
    if (this.hasCollapseFieldsTarget) {
      $(this.collapseFieldsTarget).collapse('show');
      this.collapseCheckTarget.checked = true
    }
  }

  // Disables this button but enables others, kind of like a radio. Happens on
  // click for transfer, or when an image with GPS is added to carousel. Called
  // on the element rather than the button(!) because it may be called
  // programmatically when an image is added with GPS.
  selectExifButton(element) {
    this.reenableButtons();
    // disable the button for this element, which may change the text
    const btns = this.useExifBtnTargets.filter((btn) => element.contains(btn));
    if (btns.length > 0)
      btns[0].setAttribute('disabled', 'disabled');
  }

  // enable all the buttons
  reenableButtons(event) {
    if (event?.detail?.reenableButtons === false) return;

    this.useExifBtnTargets.forEach((btn) => {
      btn.removeAttribute('disabled');
    });
  }

  /*********************/
  /*    DateUpdater    */
  /*********************/
  // Deals with synchronizing image and observation dates

  // gets or sets image date
  imageDate(itemElement, simpleDate) {
    const _img_day_select = itemElement.querySelector('[id$="_when_3i"]'),
      _img_month_select = itemElement.querySelector('[id$="_when_2i"]'),
      _img_year_field = itemElement.querySelector('[id$="_when_1i"]');

    // set it if we've got a date
    if (simpleDate) {
      _img_day_select.value = simpleDate.day;
      _img_month_select.value = simpleDate.month;
      _img_year_field.value = simpleDate.year;

      // Make these easier to find with Capybara by explicitly setting the HTML
      _img_day_select.options[_img_day_select.options.selectedIndex]
        .setAttribute('selected', 'true');
      _img_month_select.options[_img_month_select.options.selectedIndex]
        .setAttribute('selected', 'true');

      return simpleDate;
    } else {
      return this.SimpleDate(
        _img_day_select.value, _img_month_select.value, _img_year_field.value
      )
    }
  }

  // gets or sets current obs date, simpledate object updates date
  observationDate(simpleDate) {
    // These aren't targets because they are created on the fly by Rails
    // date_select, and because our year-input_controller may fire after
    // this connects, making obs_year (the select) an obsolete element.
    if (!this.obs_day || !this.obs_month || !this.obs_year) {
      this.obs_day = document.getElementById('observation_when_3i');
      this.obs_month = document.getElementById('observation_when_2i');
      this.obs_year = document.getElementById('observation_when_1i');
    }

    // set the obs date, if passed a simpleDate
    if (simpleDate && simpleDate.day && simpleDate.month &&
      simpleDate.year) {
      this.obs_day.value = simpleDate.day;
      this.obs_month.value = simpleDate.month;
      this.obs_year.value = simpleDate.year;

      // Make these easier to find with Capybara by explicitly setting the HTML
      this.obs_day.options[this.obs_day.options.selectedIndex]
        .setAttribute('selected', 'true');
      this.obs_month.options[this.obs_month.options.selectedIndex]
        .setAttribute('selected', 'true');

      return simpleDate;
    } else {
      // or get it. Have to check these values first, cannot send to function
      const day = this.obs_day?.value
      const month = this.obs_month?.value
      const year = this.obs_year?.value
      return this.SimpleDate(day, month, year)
    }
  }

  /**********************/
  /* Simple Date Object */
  /**********************/

  SimpleDate(day, month, year) {
    return {
      day: parseInt(day),
      month: parseInt(month),
      year: parseInt(year),
    }
  }

  // returns true if same
  simpleDatesAreEqual(simpleDate1, simpleDate2) {
    return simpleDate1.day == simpleDate2.day
      && simpleDate1.month == simpleDate2.month
      && simpleDate1.year == simpleDate2.year;
  }

  simpleDateAsString(simpleDate) {
    const _months = this.localized_text.months.split(' ');

    return simpleDate.day + "-"
      + _months[simpleDate.month - 1]
      + "-" + simpleDate.year;
  }

  /** Geocode Helpers **/

  // Create a map object and specify the DOM element for display.
  // showGeocodeOnMap({ params: { latLngAlt } }) {
  //   const _latLng = { lat: latLngAlt.lat, lng: latLngAlt.lng },
  //     _map_container = document.getElementById('geocode_map');

  //   _map_container.setAttribute('height', '250');

  //   // Issue: there should not be two google maps on the page.
  //   const _map = new google.maps.Map(_map_container, {
  //     center: _latLng,
  //     zoom: 12
  //   });

  //   new google.maps.Marker({
  //     map: _map,
  //     position: _latLng
  //   });
  // }
}
