import { Controller } from "@hotwired/stimulus"
import ExifReader from 'exifreader';

const internalConfig = {
  // Make some of these targets for the controller
  content: document.getElementById('content'),
  localized_text: {
    months: "January, February, March, April, May, June, July, August, September, October, November, December",
  }
}

// This controller needs to be on the whole form, to enable the large drop area.
// (formerly "observation_images" section of the form)
// Connects to data-controller="form-exif"
export default class extends Controller {
  static targets = ["carousel", "item"]

  connect() {
    this.element.dataset.stimulus = "connected";

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
    if (itemElement.hasAttribute('data-good-image')) return;
    itemElement.dataset.geocode = "";

    // extract the EXIF data (async) and populate the item and element
    this.getExifData(itemElement);
  }

  // maybe stimulus action on image?
  // extracts the exif data async;
  getExifData(itemElement) {
    const _image = itemElement.querySelector('.carousel-image');

    _image.onload = async () => {
      const _exif_data = await ExifReader.load(_image.src);
      this.populateExifData(itemElement, _exif_data);
    };
  }

  // Now that we've read the data from the loaded file, populate carousel-item
  populateExifData(itemElement, exif_data) {
    itemElement.dataset.initialized = "true"

    this.populateExifGPS(itemElement, exif_data);
    this.populateExifDate(itemElement, exif_data);

    // emit an event that form-images listens for, to set the item as processed
    this.dispatch("processed", { detail: { target: itemElement } });

    // If this is the first one, transfer the exif data to the obs fields
    // and set a flag so we don't do it again. Here because it's async.
    if (this.element.dataset?.exifUsed !== "true" &&
      itemElement.dataset?.geocode !== "") {
      this.transferExifToObsFields(itemElement);
      this.element.dataset.exifUsed = "true";
    }
  }

  populateExifGPS(itemElement, exif_data) {
    const _exif_lat = itemElement.querySelector(".exif_lat"),
      _exif_lng = itemElement.querySelector(".exif_lng"),
      _exif_alt = itemElement.querySelector(".exif_alt");

    // Geocode Logic
    // check if there is geodata on the image
    if (exif_data.GPSLatitude && exif_data.GPSLongitude) {
      const latLngAlt = this.getLatLngEXIF(exif_data);

      // Set item's data-geocode attribute so we can have a record
      itemElement.dataset.geocode = JSON.stringify(latLngAlt);

      _exif_lat.innerText = latLngAlt.lat.toFixed(5);
      _exif_lng.innerText = latLngAlt.lng.toFixed(5);
      _exif_alt.innerText = latLngAlt.alt;
    }
  }

  populateExifDate(itemElement, exif_data) {
    const _exif_date = itemElement.querySelector(".exif_date");
    _exif_date.dataset.found = 'false';

    // Image Date Logic
    if (exif_data.DateTimeOriginal) {
      // we found the date taken, let's parse it down.
      // returns an array of [YYYY,MM,DD]
      const _date_taken_array =
        exif_data.DateTimeOriginal.description.substring(' ', 10).
          split(':').reverse(),
        _exifSimpleDate = this.SimpleDate(..._date_taken_array);

      this.imageDate(itemElement, _exifSimpleDate);

      // shows the exif date by the photo
      itemElement.dataset.exif_date = JSON.stringify(_exifSimpleDate);
      _exif_date.innerText = this.simpleDateAsString(_exifSimpleDate);
      _exif_date.dataset.found = "true";
    }
    // no date was found in EXIF data
    else {
      // Use observation date
      this.imageDate(itemElement, this.observationDate());
    }
  }

  // Click callback so .exif_date will set the image date if clicked
  exifToImageDate(event) {
    const _itemElement = event.target.closest(".item"),
      _exifSimpleDate = JSON.parse(_itemElement.dataset.exif_date);
    debugger
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
    this.selectExifButton('.use_exif_btn', element);
    const _exif_data = element.dataset,
      _obs_lat = document.getElementById('observation_lat'),
      _obs_lng = document.getElementById('observation_lng'),
      _obs_alt = document.getElementById('observation_alt'),
      _event = new Event('change');

    if (_exif_data.geocode && _exif_data.geocode !== "") {
      const latLngAlt = JSON.parse(_exif_data.geocode);

      _obs_lat.value = latLngAlt.lat;
      _obs_lng.value = latLngAlt.lng;
      _obs_alt.value = latLngAlt.alt;
      _obs_lat.dispatchEvent(_event); // triggers change to update the map
    }
    if (_exif_data.exif_date) {
      const _exifSimpleDate = JSON.parse(_exif_data.exif_date);
      this.observationDate(_exifSimpleDate);
    }
  }

  // Happens on click for transfer, disabling this button but enabling others.
  // Kind of like radio
  selectExifButton(selector, element) {
    // enable all the buttons
    this.carouselTarget.querySelectorAll(selector).forEach((element) => {
      element.removeAttribute('disabled');
    });
    // disable the button that was clicked, which may change the text
    element.querySelector(selector).setAttribute('disabled', 'disabled');
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

  getLatLngEXIF(exifObject) {
    let lat = exifObject.GPSLatitude.description;
    let lng = exifObject.GPSLongitude.description;

    const alt = exifObject.GPSAltitude ? (exifObject.GPSAltitude.value[0]
      / exifObject.GPSAltitude.value[1]).toFixed(0) + " m" : "";

    // make sure you don't end up on the wrong side of the world
    lng = exifObject.GPSLongitudeRef.value[0] == "W" ? lng * -1 : lng;
    lat = exifObject.GPSLatitudeRef.value[0] == "S" ? lat * -1 : lat;

    return { lat, lng, alt };
  }

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
