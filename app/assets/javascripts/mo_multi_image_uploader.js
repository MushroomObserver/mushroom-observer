//= require exif.js

class MOMultiImageUploader {

  constructor(localization = {}) {
    // Internal Variable Definitions.
    const internal_config = {
      form: document.forms.namedItem("observation_form"),
      block_form_submission: true,
      select_files_button: document.getElementById('multiple_images_button'),
      content: document.getElementById('content'),
      // container to insert images into
      add_img_container: document.getElementById("added_images_container"),
      get_template_uri: "/ajax/multi_image_template",
      upload_image_uri: "/ajax/create_image_object",
      // progress_uri: "/ajax/upload_progress",
      dots: [".", "..", "..."],
      good_images: document.getElementById('good_images'),
      remove_links: document.querySelectorAll(".remove_image_link"),
      obs_day: document.getElementById('observation_when_3i'),
      obs_month: document.getElementById('observation_when_2i'),
      obs_year: document.getElementById('observation_when_1i'),
      img_radio_container: document.getElementById('image_date_radio_container'),
      obs_radio_container: document.getElementById('observation_date_radio_container'),
      fix_date_submit: document.getElementById('fix_dates'),
      ignore_date_submit: document.getElementById('ignore_dates'),
      img_messages: document.getElementById("image_messages"),
      geocode_radio_container: document.getElementById('geocode_radio_container'),
      set_geocode_btn: document.getElementById('set_geocode'),
      ignore_geocode_btn: document.getElementById('ignore_geocode'),
      geocode_messages: document.getElementById('geocode_messages'),
      localized_text: {
        uploading_text: "Uploading",
        image_too_big_text: "This image is too large. Image files must be less than 20Mb.",
        creating_observation_text: "Creating Observation...",
        months: "January, February, March, April, May, June, July, August, September, October, November, December",
        show_on_map: "Show on map",
        something_went_wrong: "Something went wrong while uploading image."
      }
    }

    Object.assign(this, internal_config);
    Object.assign(this.localized_text, localization);

    this.submit_buttons = this.form.querySelectorAll('input[type="submit"]');
    this.max_image_size = this.add_img_container.dataset.upload_max_size;

    this.fileStore = new FileStore(this);
    this.dateUpdater = new DateUpdater(this);

    // function of the Uploader instance, not the constructor
    this.set_bindings();
  }

  set_bindings() {
    // make sure submit buttons are enabled when the dom is loaded!
    this.submit_buttons.setAttribute('disabled', false);

    // was bind('click.setGeoCodeBind'
    this.set_geocode_btn.onclick = function () {
      const _selectedItemData =
        document.querySelector('input[name=fix_geocode]:checked').dataset;

      if (_selectedItemData) {
        document.getElementById('observation_lat')
          .value = _selectedItemData.geocode.latitude;
        document.getElementById('observation_long')
          .value = _selectedItemData.geocode.longitude;
        document.getElementById('observation_alt')
          .value = _selectedItemData.geocode.altitude;
        this.geocode_messages.hide('slow');
      }
    };

    this.ignore_geocode_btn.onclick = function () {
      this.geocode_messages.hide('slow');
    };


    document.body.querySelectorAll('[data-role="show_on_map"]')
      .onclick = function () {
        this.showGeocodeonMap(this.dataset.geocode);
      };

    // was bind('click.fixDateBind
    this.fix_date_submit.onclick = function () {
      const _selectedItemData =
        document.querySelector('input[name=fix_date]:checked').dataset;

      if (_selectedItemData && _selectedItemData.date) {
        this.dateUpdater.fixDates(
          _selectedItemData.date, _selectedItemData.target
        );
      }
    };

    // was bind('click.ignoreDateBind'
    this.ignore_date_submit.onclick = function () {
      this.img_messages.hide('slow');
    };

    this.obs_year.onchange = function () {
      this.dateUpdater.updateObservationDateRadio()
    };
    this.obs_month.onchange = function () {
      this.dateUpdater.updateObservationDateRadio()
    };
    this.obs_day.onchange = function () {
      this.dateUpdater.updateObservationDateRadio()
    };


    // Drag and Drop bindings on the window

    ['dragover', 'dragenter'].forEach(() => {
      this.content.addEventListener(e, function (e) {
        if (e.preventDefault) { e.preventDefault(); }
        document.getElementById('right_side').classList.add('dashed-border');
        return false;
      })
    })

    ['dragend', 'dragleave', 'dragexit'].forEach(() => {
      this.content.addEventListener(e, function (e) {
        document.getElementById('right_side').classList.remove('dashed-border');
      })
    })

    this.content.ondrop = function (e) {
      if (e.preventDefault) { e.preventDefault(); }  // stops the browser from leaving page
      document.getElementById('right_side').classList.remove('dashed-border');
      const dataTransfer = e.originalEvent.dataTransfer;
      if (dataTransfer.files.length > 0)
        this.fileStore.addFiles(dataTransfer.files);
      // There are issues to work out concerning dragging and dropping
      // images from other websites into the observation form.
      // else
      //   fileStore.addUrl(dataTransfer.getData('Text'));
    };

    // Detect when files are added from browser
    this.select_files_button.onchange = function () {
      const files = this[0].files; // Get the files from the browser
      this.fileStore.addFiles(files);
    };

    // IMPORTANT:  This allows the user to update the thumbnail on the edit
    // observation view.
    document
      .querySelectorAll('[type="radio"][name="observation[thumb_image_id]"]')
      .onchange = function () {
        document.getElementById('observation_thumb_image_id')
          .value = this.value;
      };

    // Logic for setting the default thumbnail
    document.body
      .querySelectorAll('[data-role="set_as_default_thumbnail"]')
      .onclick = function (event) {
        // `this` is the link clicked to make default image
        event.preventDefault();

        // reset selections
        // remove hidden from the links
        document.querySelectorAll('[data-role="set_as_default_thumbnail"]')
          .classList.remove('hidden');
        // add hidden to the default thumbnail text
        document.querySelectorAll('.is_default_thumbnail')
          .classList.add('hidden');
        // reset the chcked default thumbnail
        document.querySelectorAll('input[type="radio"][name="observation[thumb_image_id]"]').setAttribute('checked', false);


        // set selections
        // add hidden to the link clicked
        this.classList.add('hidden');
        // show that the image is default
        const siblings = _this.parentNode.childNodes

        siblings.querySelectorAll('.is_default_thumbnail')
          .classList.remove('hidden');
        // adjust hidden radio button to select default thumbnail
        siblings.querySelectorAll('input[type="radio"][name="observation[thumb_image_id]"]').setAttribute('checked', true);
      }

    // Detect when a user submits observation; includes upload logic

    this.form.onsubmit = function (event) {
      // event.preventDefault();
      if (this.block_form_submission) {
        this.fileStore.uploadAll();
        return false;
      }
      return true;
    };
  }

  /*********************/
  /*    Helpers    */
  /*********************/

  generateUUID() {
    return 'xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
      const r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }

  /** Geocode Helpers **/

  makeGeocodeRadioBtn(latLngObjct) {
    const geocode = JSON.stringify(latLngObjct),
      geocodeformap = JSON.stringify(latLngObjct),
      geoCodeStr = latLngObjct.latitude.toFixed(5) + ", "
        + latLngObjct.longitude.toFixed(5),

      html = "<div class='radio'><label><input type='radio' data-geocode='"
        + geocode + "' name='fix_geocode'/>" + geoCodeStr + "</label> "
        + "<a href='#geocode_map' data-role='show_on_map' class='ml-3' "
        + "data-geocode='" + geocodeformap + "'>"
        + this.localized_text.show_on_map + "</a></div>";

    return html;
  }

  getLatitudeLongitudeFromEXIF(exifObject) {
    let lat = exifObject.GPSLatitude[0]
      + (exifObject.GPSLatitude[1] / 60.0)
      + (exifObject.GPSLatitude[2] / 3600.0);
    let long = exifObject.GPSLongitude[0]
      + (exifObject.GPSLongitude[1] / 60.0)
      + (exifObject.GPSLongitude[2] / 3600.0);

    const alt = exifObject.GPSAltitude ? (exifObject.GPSAltitude.numerator
      / exifObject.GPSAltitude.denominator).toFixed(0) + " m" : "";

    // make sure you don't end up on the wrong side of the world
    long = exifObject.GPSLongitudeRef == "W" ? long * -1 : long;
    lat = exifObject.GPSLatitudeRef == "S" ? lat * -1 : lat;

    return {
      latitude: lat,
      longitude: long,
      altitude: alt
    }
  }

  showGeocodeonMap(latLngObj) {
    // Create a map object and specify the DOM element for display.
    const obsLatLongformat = {
      lat: latLngObj.latitude, lng: latLngObj.longitude
    }
    // jQuery('#geocode_map').width('100%'); // css class w-100 on the div
    document.getElementById('geocode_map').setAttribute('height', '250');

    const map = new google.maps.Map(document.getElementById('geocode_map'), {
      center: obsLatLongformat,
      zoom: 12
    });

    const marker = new google.maps.Marker({
      map: map,
      position: obsLatLongformat
    });
  }
}

/*********************/
/* Simple Date Class */
/*********************/
class SimpleDate {
  constructor(day, month, year, uploader) {
    this.Uploader = uploader;
    this.day = parseInt(day);
    this.month = parseInt(month);
    this.year = parseInt(year);
  }

  areEqual(simpleDate) { //returns true if same
    // const _this = this;
    return this.month == simpleDate.month && this.day == simpleDate.day
      && this.year == simpleDate.year;
  }

  asDateString() {
    const _months = this.Uploader.localized_text.months.split(' ');
    return this.day + "-" + _months[this.month - 1] + "-" + this.year;
  }
};

/*********************/
/*    DateUpdater    */
/*********************/
// Deals with synchronizing image and observation dates through
// a message box.
class DateUpdater {
  constructor(uploader) {
    this.Uploader = uploader;
  }

  // will check differences between the image dates and observation dates
  areDatesInconsistent() {
    const _obsDate = this.observationDate(),
      _distinctDates = this.Uploader.fileStore.getDistinctImageDates();

    for (let i = 0; i < _distinctDates.length; i++) {
      if (!_distinctDates[i].areEqual(_obsDate))
        return true;
    }

    return false;
  }

  refreshBox() {
    const _distinctImgDates = this.Uploader.fileStore.getDistinctImageDates(),
      _obsDate = this.observationDate();

    this.Uploader.img_radio_container.html = '';
    this.Uploader.obs_radio_container.html = '';
    this.makeObservationDateRadio(obsDate);

    _distinctImgDates.forEach(function (simpleDate) {
      if (!_obsDate.areEqual(simpleDate))
        this.makeImageDateRadio(simpleDate);
    });

    if (this.areDatesInconsistent()) {
      this.Uploader.img_messages.show('slow');
    } else {
      this.Uploader.img_messages.hide('slow')
    }
  }

  fixDates = function (simpleDate, target) {
    if (target == "image")
      this.Uploader.fileStore.updateImageDates(simpleDate);
    if (target == "observation")
      this.observationDate(simpleDate);
    this.Uploader.img_messages.hide('slow');
  }

  makeImageDateRadio(simpleDate) {
    const _date = JSON.stringify(simpleDate),
      _date_string = simpleDate.asDateString(),
      _html = "<div class='radio'><label><input type='radio' data-target='observation' data-date='" + _date + "' name='fix_date'/>" + _date_string + "</label></div>"
    // html = html.replace('{{date}}', JSON.stringify(simpleDate));
    // html = html.replace('{{dateStr}}', simpleDate.asDateString());

    this.Uploader.img_radio_container.append(_html);
  }

  makeObservationDateRadio(simpleDate) {
    const _date = JSON.stringify(simpleDate),
      _date_string = simpleDate.asDateString(),
      _html = "<div class='radio'><label><input type='radio' data-target='image' data-date='" + _date + "' name='fix_date'/><span>" + _date_string + "</span></label></div>";
    // html = html.replace('{{date}}', JSON.stringify(simpleDate));
    // html = html.replace('{{dateStr}}', simpleDate.asDateString());

    // const obs_radio = jQuery(html);
    this.Uploader.obs_radio_container.append(_html);
  }

  updateObservationDateRadio() {
    // const _this = this;
    // _currentObsDate is an instance of Uploader.SimpleDate(values)
    const _currentObsDate = this.observationDate();

    this.Uploader.obs_radio_container.querySelectorAll('input')
      .forEach((elem) => { elem.dataset.date = _currentObsDate; })

    this.Uploader.obs_radio_container.querySelectorAll('span')
      .forEach((elem) => { elem.text = _currentObsDate.asDateString(); })

    if (this.areDatesInconsistent())
      this.Uploader.img_messages.show('slow');
  }

  // undefined gets current date, simpledate object updates date
  observationDate = function (simpleDate) {
    let _date_values;

    if (simpleDate && simpleDate.day && simpleDate.month &&
      simpleDate.year) {
      _date_values = [
        this.Uploader.obs_day.value = simpleDate.day,
        this.Uploader.obs_month.value = simpleDate.month,
        this.Uploader.obs_year.value = simpleDate.year,
      ]
    }
    return new SimpleDate(_date_values);
  }
}

/*********************/
/*     FileStore     */
/*********************/
// Container for the image files.
// Modifies attributes of the passed Uploader.
class FileStore {
  constructor(uploader) {
    this.Uploader = uploader;
    this.fileStoreItems = [];
    this.fileDictionary = {};
    this.areAllProcessed = function () {
      for (let i = 0; i < this.fileStoreItems.length; i++) {
        if (!this.fileStoreItems[i].processed)
          return false;
      }
      return true;
    }
  }

  addFiles(files) {
    // const _this = this;

    // loop through attached files, make sure we aren't adding duplicates
    for (let i = 0; i < files.length; i++) {
      // stop adding the file, one with this exact size is already attached
      // TODO: What are the odds of this?
      if (this.fileDictionary[files[i].size] != undefined) {
        continue;
      }

      // uuid is used as the index for the ruby form template. // **
      const _fileStoreItem = new FileStoreItem(files[i], generateUUID());
      // add an item to the dictionary with the file size as the key
      this.fileDictionary[files[i].size] = _fileStoreItem;
      this.fileStoreItems.push(_fileStoreItem)
    }

    // check status of when all the selected files have processed.
    function checkStatus() {
      setTimeout(function () {
        if (!this.areAllProcessed()) {
          checkStatus();
        } else {
          this.Uploader.dateUpdater.refreshBox(); // **
        }
      }, 30)
    }
    checkStatus();
  }

  addUrl(url) {
    // const _this = this;
    if (this.fileDictionary[url] == undefined) {
      // **
      const _fileStoreItem = new FileStoreItem(url, generateUUID());

      this.fileDictionary[url] = _fileStoreItem;
      this.fileStoreItems.push(_fileStoreItem);
    }
  }

  updateImageDates(simpleDate) {
    // const _this = this;
    this.fileStoreItems.forEach(function (fileStoreItem) {
      fileStoreItem.imageDate(simpleDate);
    });
  }

  getDistinctImageDates() {
    // const _this = this,
    const _testAgainst = "",
      _distinct = [];

    for (let i = 0; i < this.fileStoreItems.length; i++) {
      const _ds = this.fileStoreItems[i].imageDate().asDateString();
      if (_testAgainst.indexOf(_ds) != -1)
        continue;
      _testAgainst += _ds;
      _distinct.push(this.fileStoreItems[i].imageDate())
    }

    return _distinct;
  }

  // remove all the images as they were uploaded!
  destroyAll() {
    this.fileStoreItems.forEach(function (item) {
      item.destroy();
    });
  }

  uploadAll() {
    // disable submit and remove image buttons during upload process.
    this.Uploader.submit_buttons.setAttribute('disabled', 'true');
    this.Uploader.remove_links.hide();

    // callback function to move through the the images to upload
    function getNextImage() {
      this.fileStoreItems[0].destroy();
      return this.fileStoreItems[0];
    }

    function onUploadedCallback() {
      const _nextInLine = getNextImage();
      if (_nextInLine)
        _nextInLine.upload(onUploadedCallback);
      else {
        // now the form will be submitted without hitting the uploads.
        this.Uploader.block_form_submission = false;
        this.Uploader.submit_buttons.value =
          this.Uploader.localized_text.creating_observation_text;
        this.Uploader.form.submit();
      }
    }

    const _firstUpload = this.fileStoreItems[0];
    if (_firstUpload) {
      // uploads first image. if we have one.
      _firstUpload.upload(onUploadedCallback);
    }
    else {
      // no images to upload, submit form
      this.Uploader.block_form_submission = false;
      this.Uploader.form.submit();
    }

    return false;
  }
}

/*********************/
/*   FileStoreItem   */
/*********************/
// Contains information about an image file.
class FileStoreItem {

  constructor(file_or_url, uuid, uploader) {
    this.Uploader = uploader;
    if (typeof file_or_url == "string") {
      this.is_file = false;
      this.url = file_or_url;
    } else {
      this.is_file = true;
      this.file = file_or_url;
    }
    this.uuid = uuid;
    this.dom_element = null;
    this.exif_data = null;
    this.processed = false; // check the async status of files
    this.getTemplateHtml(); // kicks off process of creating image and such
  }

  // does an ajax request to get the template, then formats it
  // the format function adds to HTML
  getTemplateHtml() {
    // const _this = this;
    jQuery.get(this.Uploader.get_template_uri, {
      img_number: _this.uuid
    }, function (data) {
      // on success
      // the data returned is the raw HTML template
      this.createTemplate(data)
      // extract the EXIF data (async) and then load it
      this.getExifData();
      // load image as base64 async
      this.loadImage();
    });
  }

  createTemplate(html_string) {
    // const _this = this;

    html_string = html_string
      .replace('{{img_file_name}}', this.file_name())
      .replace('{{img_file_size}}', this.is_file ?
        Math.floor((_this.file_size() / 1024)) + "kb" : "");

    // Create the DOM element and add it to FileStoreItem;
    this.dom_element = document.createElement(html_string);

    if (_this.file_size() > this.max_image_size)
      this.dom_element.querySelectorAll('.warn-text').text =
        this.Uploader.localized_text.image_too_big_text;

    // add it to the page
    this.Uploader.add_img_container.append(this.dom_element);

    // bind the destroy function
    this.dom_element.querySelectorAll('.remove_image_link')
      .onclick = function () {
        this.destroy();
        this.Uploader.dateUpdater.refreshBox();
      };

    this.dom_element.querySelectorAll('select')
      .onchange = function () {
        this.Uploader.dateUpdater.refreshBox();
      };
  }

  file_name() {
    if (this.is_file)
      return this.file.name;
    else
      return decodeURI(this.url.replace(/.*\//, ""));
  }

  file_size() {
    if (this.is_file)
      return this.file.size;
    else
      return 0; // any way to get size from url??
  }

  loadImage() {
    if (this.is_file) {
      const fileReader = new FileReader();

      fileReader.onload = function (fileLoadedEvent) {
        // find the actual image element
        const _img = this.dom_element.querySelectorAll('.img-responsive')[0];
        // get image element in container and set the src to base64 img url
        _img.setAttribute('src', fileLoadedEvent.target.result);
      };

      fileReader.readAsDataURL(this.file);
    } else {
      const _img = this.dom_element.querySelectorAll('.img-responsive')[0];
      _img.setAttribute('src', _this.url)
        .onerror = function () {
          alert("Couldn't read image from: " + _this.url);
          this.destroy();
        };
    }
  }

  // extracts the exif data async;
  getExifData() {
    const _fsItem = this;
    _fsItem.dom_element.querySelectorAll('.img-responsive')[0]
      .onload = function () {
        EXIF.getData(this, function () {
          _fsItem.exif_data = this.exifdata;
          // apply the data to the DOM
          _fsItem.applyExifData();
        });
      };
  }

  // applies exif data to the DOM element, must already be attached
  applyExifData() {
    let _exif_date_taken;
    const _exif = this.exif_data;

    if (this.dom_element == null) {
      console.warn("Error: Dom element for this file has not been created, so cannot update it with exif data!");
      return;
    }

    // Geocode Logic
    // check if there is geodata on the image
    if (_exif.GPSLatitude && _exif.GPSLongitude) {

      const latLngObject = getLatitudeLongitudeFromEXIF(_exif),
        radioBtnToInsert = makeGeocodeRadioBtn(latLngObject);

      if (geocode_radio_container
        .querySelectorAll('input[type="radio"]').length === 0) {
        this.Uploader.geocode_messages.show('medium');
        this.Uploader.geocode_radio_container.append(radioBtnToInsert);
      }

      // don't add geocodes that are only slightly different
      else {
        const shouldAddGeocode = true;

        this.Uploader.geocode_radio_container
          .querySelectorAll('input[type="radio"]')
          .forEach(function (index, element) {
            const existingGeocode = element.dataset.geocode;
            const latDif = Math.abs(latLngObject.latitude)
              - Math.abs(existingGeocode.latitude);
            const longDif = Math.abs(latLngObject.longitude)
              - Math.abs(existingGeocode.longitude);

            if ((Math.abs(latDif) < 0.0002) || Math.abs(longDif) < 0.0002)
              shouldAddGeocode = false;
          });

        if (shouldAddGeocode)
          this.Uploader.geocode_radio_container.append(radioBtnToInsert);
      }
    }

    // Image Date Logic
    _exif_date_taken = this.exif_data.DateTimeOriginal;

    if (_exif_date_taken) {
      // we found the date taken, let's parse it down.
      // returns an array of [YYYY,MM,DD]
      const _date_taken_array =
        _exif_date_taken.substring(' ', 10).split(':'),
        _exifSimpleDate = new SimpleDate(_date_taken_array.reverse());

      this.imageDate(_exifSimpleDate);

      const _camera_date = this.dom_element.find(".camera_date_text");
      _camera_date.text = _exifSimpleDate.asDateString();//shows the exif date by the photo
      _camera_date.dataset.exif_date = _exifSimpleDate;
      _camera_date.onclick = function () {
        this.imageDate(_exifSimpleDate);
        this.Uploader.dateUpdater.refreshBox();
      }
    }
    // no date was found in EXIF data
    else {
      // Use observation date
      this.imageDate(this.Uploader.dateUpdater.observationDate());
    }

    this.processed = true;
  }

  imageDate(simpleDate) {
    const _day = this.dom_element.querySelectorAll('select')[0],
      _month = this.dom_element.querySelectorAll('select')[1],
      _year = this.dom_element.querySelectorAll('input')[2];
    if (simpleDate) {
      _day.value = simpleDate.day;
      _month.value = simpleDate.month;
      _year.value = simpleDate.year;
    }
    return new SimpleDate(_day.value, _month.value, _year.value);
  }

  getUserEnteredInfo() {
    return {
      day: this.dom_element.querySelectorAll('select')[0].value,
      month: this.dom_element.querySelectorAll('select')[1].value,
      year: this.dom_element.querySelectorAll('input')[2].value,
      license: this.dom_element.querySelectorAll('select')[2].value,
      notes: this.dom_element.querySelectorAll('textarea')[0].value,
      copyright_holder: this.dom_element.querySelectorAll('input')[1].value
    };
  }

  asformData() {
    const _info = this.getUserEnteredInfo(),
      _fd = new formData();

    if (this.file_size() > this.Uploader.max_image_size)
      return null;

    if (this.is_file)
      _fd.append("image[upload]", this.file, this.file_name());
    else
      _fd.append("image[url]", this.url);
    _fd.append("image[when][3i]", _info.day);
    _fd.append("image[when][2i]", _info.month);
    _fd.append("image[when][1i]", _info.year);
    _fd.append("image[notes]", _info.notes);
    _fd.append("image[copyright_holder]", _info.copyright_holder);
    _fd.append("image[license]", _info.license);
    _fd.append("image[original_name]", this.file_name());
    return _fd;
  }

  incrementProgressBar(decimalPercentage) {
    const _container = this.dom_element
      .querySelectorAll(".added_image_name_container"),
      // if we don't have percentage,  just set it to 0 percent
      _percent_string = decimalPercentage ?
        parseInt(decimalPercentage * 100).toString() + "%" : "0%";

    if (!this.isUploading) {
      this.isUploading = true;
      _container.html =
        '<div class="col-xs-12" style="z-index: 1">'
        + '<strong class="progress-text">'
        + this.Uploader.localized_text.uploading_text + '</strong></div>'
        + '<div class="progress-bar position-absolute" '
        + 'style="width: 0%; height: 1.5em; background: #51B973; '
        + 'z-index: 0;"></div>'

      doDots(1);
    } else {
      _container.querySelectorAll(".progress-bar").animate({ width: _percent_string }, decimalPercentage == 1 ? 1000 : 1500, "linear");
      // 1500: a little extra to patch over gap between sending request
      // for next progress update and actually receiving it, which occurs
      // after a second is up... but not after image is done, no more
      // progress updates required then.
    }

    function doDots(i) {
      setTimeout(function () {
        if (i < 900) {
          _container.querySelectorAll(".progress-text").html =
            this.Uploader.localized_text.uploading_text +
            this.Uploader.dots[i % 3];
          doDots(++i);
        }
      }, 333)
    }
  }

  upload(onUploadedCallback) {
    const // _this = this,
      xhrReq = new XMLHttpRequest(),
      progress = null;
    // let update = null;

    this.Uploader.submit_buttons.value =
      this.Uploader.localized_text.uploading_text + '...';
    this.incrementProgressBar();

    // after image has been created.
    xhrReq.onreadystatechange = function () {
      if (xhrReq.readyState == 4) {
        if (xhrReq.status == 200) {
          const _image = JSON.parse(xhrReq.response);
          const _good_image_vals = this.Uploader.good_images.value ?
            this.Uploader.good_images.value : "";
          // add id to the good images form field.
          this.Uploader.good_images.value = _good_image_vals.length == 0 ?
            _image.id : _good_image_vals + ' ' + _image.id;
          // set the thumbnail if it is selected
          if (this.dom_element
            .querySelector('input[name="observation[thumb_image_id]"]')
            .checked) {
            document.getElementById('observation_thumb_image_id')
              .value = image.id;
          }
        } else if (xhrReq.response) {
          alert(xhrReq.response);
        } else {
          alert(this.Uploader.localized_text.something_went_wrong);
        }
        if (progress) window.clearTimeout(progress);
        this.incrementProgressBar(1);
        this.dom_element.hide('slow');
        onUploadedCallback(); // passed to this function
      }
    };

    // This is currently disabled in nginx, so no sense making the request.
    // update = function() {
    //   const req = new XMLHttpRequest();
    //   req.open("GET", this.progress_uri, 1);
    //   req.setRequestHeader("X-Progress-ID", _this.uuid);
    //   req.onreadystatechange = function () {
    //   if (req.readyState == 4 && req.status == 200) {
    //     const upload = eval(req.responseText);
    //     if (upload.state == "done" || upload.state == "uploading") {
    //     _this.incrementProgressBar(upload.received / upload.size);
    //     progress = window.setTimeout(update, 1000);
    //     } else {
    //     window.clearTimeout(progress);
    //     progress = null;
    //     }
    //   }
    //   };
    //   req.send(null);
    // };
    // progress = window.setTimeout(update, 1000);

    // Note: Add the event listeners before calling open() on the request.
    xhrReq.open("POST", this.Uploader.upload_image_uri, true);
    xhrReq.setRequestHeader("X-Progress-ID", this.uuid);
    const _fd = this.asformData(); // Send the form
    if (_fd != null) {
      xhrReq.send(_fd);
    } else {
      alert(this.Uploader.localized_text.something_went_wrong);
      onUploadedCallback();
    }
  }

  destroy() {
    // remove element from the dom;
    this.dom_element.remove();
    if (this.is_file)
      // remove the file from the dictionary
      delete this.Uploader.fileStore.fileDictionary[this.file_size()];
    else
      // remove the file from the dictionary
      delete this.Uploader.fileStore.fileDictionary[this.url];

    // removes the file from the array
    const idx = this.Uploader.fileStore.fileStoreItems.indexOf(this);
    if (idx > -1)
      // removes the file from the array
      this.Uploader.fileStore.fileStoreItems.splice(idx, 1);
  }
}

