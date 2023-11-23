import { Controller } from "@hotwired/stimulus"
import ExifReader from 'exifreader';

const internalConfig = {
  // Make some of these targets for the controller
  block_form_submission: true,
  content: document.getElementById('content'),
  // These aren't targets because outside scope of this controller (obs images)
  obs_day: document.getElementById('observation_when_3i'),
  obs_month: document.getElementById('observation_when_2i'),
  obs_year: document.getElementById('observation_when_1i'),
  get_template_uri: "/observations/images/uploads/new",
  upload_image_uri: "/observations/images/uploads",
  // progress_uri: "/ajax/upload_progress",
  dots: [".", "..", "..."],
  localized_text: {
    uploading_text: "Uploading",
    image_too_big_text: "This image is too large. Image files must be less than 20Mb.",
    creating_observation_text: "Creating Observation...",
    months: "January, February, March, April, May, June, July, August, September, October, November, December",
    show_on_map: "Show on map",
    something_went_wrong: "Something went wrong while uploading image."
  }
}

// This needs to be on the whole "observation_images" section of the form.
// Connects to data-controller="obs-form-images"
export default class extends Controller {
  static targets = ["imgMessages", "imgDateRadios", "obsDateRadios",
    "gpsMessages", "gpsRadios", "setLatLngAlt", "ignoreGps", "imageGpsMap",
    "addedImages", "goodImages", "thumbImageId", "setThumbImg", "isThumbImg",
    "thumbImgRadio", "removeImg"]

  initialize() {
  }

  connect() {
    this.element.dataset.stimulus = "connected";

    Object.assign(this, internalConfig);
    Object.assign(this.localized_text,
      JSON.parse(this.element.dataset.localization));

    // Doesn't seem reliably available from internalConfig.
    this.form = document.forms.observation_form;
    this.submit_buttons =
      document.forms.observation_form.querySelectorAll('input[type="submit"]');
    this.max_image_size = this.element.dataset.upload_max_size;

    this.fileStore = { items: [], index: {} }

    this.set_bindings();
  }

  set_bindings() {
    // make sure submit buttons are enabled when the dom is loaded
    this.submit_buttons.forEach((element) => {
      element.disabled = false;
    });

    // Drag and Drop bindings on the window
    this.content.addEventListener('dragover', function (e) {
      e.preventDefault();
      addDashedBorder();
      return false;
    });
    this.content.addEventListener('dragenter', function (e) {
      e.preventDefault();
      addDashedBorder();
      return false;
    });
    this.content.addEventListener('dragend', removeDashedBorder());
    this.content.addEventListener('dragleave', removeDashedBorder());
    this.content.addEventListener('dragexit', removeDashedBorder());

    function addDashedBorder() {
      document.getElementById('right_side').classList.add('dashed-border');
    }

    function removeDashedBorder() {
      document.getElementById('right_side').classList.remove('dashed-border');
    }

    // ADDING FILES
    this.content.ondrop = (e) => {
      // stops the browser from leaving page
      if (e.preventDefault) { e.preventDefault(); }
      removeDashedBorder();

      const dataTransfer = e.dataTransfer;
      if (dataTransfer.files.length > 0)
        this.addFiles(dataTransfer.files);
      // There are issues to work out concerning dragging and dropping
      // images from other websites into the observation form.
      // else
      //   fileStore.addUrl(dataTransfer.getData('Text'));
    };

    // Detect when a user submits observation; includes upload logic
    this.form.onsubmit = (event) => {
      if (this.block_form_submission) {
        this.uploadAll();
        return false;
      }
      return true;
    };
  }

  fixDates() {
    const _selectedItem =
      document.querySelector('input[name=fix_date]:checked');

    if (_selectedItem && _selectedItem.hasAttribute('data-date')) {
      const _itemData = _selectedItem.dataset;

      this.reconcileDates(JSON.parse(_itemData.date), _itemData.target);
    }
  }

  ignoreDates() { this.hide(this.imageMessagesTarget); }

  setGps() {
    const _selectedItem =
      document.querySelector('input[name=fix_geocode]:checked');

    if (_selectedItem && _selectedItem.hasAttribute('data-geocode')) {
      const _gps = JSON.parse(_selectedItem.dataset.geocode);

      document.getElementById('observation_lat').value = _gps.latitude;
      document.getElementById('observation_long').value = _gps.longitude;
      document.getElementById('observation_alt').value = _gps.altitude;
      this.hide(this.gpsMessagesTarget);
    }
  }

  ignoreGps() { this.hide(this.gpsMessagesTarget); }

  setObsThumbnail(event) {
    // event.target is the button clicked to make whichever the default image
    const elem = event.target;

    // reset selections
    // remove hidden from the links
    this.setThumbImgTargets.forEach((elem) => {
      elem.classList.remove('hidden');
    });
    // add hidden to the default thumbnail text
    this.isThumbImgTargets.forEach((elem) => {
      elem.classList.add('hidden');
    });
    // reset the checked default thumbnail
    this.thumbImgRadioTargets.forEach((elem) => {
      elem.setAttribute('checked', false);
    });

    // set sibling selections... don't know how to use targets here
    // add hidden to the link clicked
    elem.classList.add('hidden');
    // show that the image is default
    elem.parentNode.querySelector(
      '.is_thumb_image'
    ).classList.remove('hidden');
    // adjust hidden radio button to select obs thumbnail
    elem.parentNode.querySelector(
      'input[type="radio"][name="observation[thumb_image_id]"]'
      // ).setAttribute('checked', true);
    ).trigger("click") // to trigger setHiidenThumbField below.
  }

  // this just sets the hidden field value. do this directly or trigger click
  setHiddenThumbField(event) {
    this.thumbImageIdTarget.setAttribute('value', event.target.value);
  }

  addSelectedFiles(event) {
    // Get the files from the browser
    const files = event.target.files;
    this.addFiles(files);
    event.target.value = "";
  }

  /*********************/
  /*     FileStore     */
  /*********************/
  // Container for the image files.

  areAllItemsProcessed() {
    for (let i = 0; i < this.fileStore.items.length; i++) {
      if (!this.fileStore.items[i].processed)
        return false;
    }
    return true;
  }

  addFiles(files) {
    // loop through attached files
    for (let i = 0; i < files.length; i++) {
      // uuid is used as the index for the ruby form template. // **
      const _item = this.FileStoreItem(files[i], this.generateUUID());
      this.loadAndDisplayItem(_item);

      // add an item to the dictionary with the file size as the key
      this.fileStore.index[files[i].size] = _item;
      this.fileStore.items.push(_item)
    }

    // check status of when all the selected files have processed.
    this.checkStoreStatus();
  }

  checkStoreStatus() {
    setTimeout(() => {
      if (!this.areAllItemsProcessed()) {
        this.checkStoreStatus();
      } else {
        this.refreshImageMessages();
        this.refreshGeocodeMessages();
      }
    }, 30)
  }

  addUrl(url) {
    if (this.fileStore.index[url] == undefined) {
      const _item = this.FileStoreItem(url, this.generateUUID());
      this.loadAndDisplayItem(_item);

      this.fileStore.index[url] = _item;
      this.fileStore.items.push(_item);
    }
  }

  updateImageDates(simpleDate) {
    this.fileStore.items.forEach((item) => {
      this.imageDate(item, simpleDate);
    });
  }

  getDistinctImageDates() {
    let _testAgainst = "";
    const _distinct = [];

    for (let i = 0; i < this.fileStore.items.length; i++) {
      const _ds =
        this.simpleDateAsString(this.imageDate(this.fileStore.items[i]));

      if (_testAgainst.indexOf(_ds) != -1)
        continue;

      _testAgainst += _ds;
      _distinct.push(this.imageDate(this.fileStore.items[i]))
    }

    return _distinct;
  }

  // remove all the images as they were uploaded. unused
  removeAll() {
    // or maybe bump the item from the fileStore.items? indexOf and splice
    this.fileStore.items.forEach((item) => { this.removeItem(item) });
  }

  uploadAll() {
    // disable submit and remove image buttons during upload process.
    this.submit_buttons.forEach(
      (element) => { element.disabled = true }
    );
    // Note that remove image links are not present at initialization
    this.removeImgTargets.forEach((elem) => {
      this.hide(elem);
    });

    let _firstUpload;
    // uploads first image. if we have one, and bumps it off the list
    if (_firstUpload = this.fileStore.items.shift()) {
      this.uploadItem(_firstUpload);
    } else {
      // no images to upload, submit form
      this.block_form_submission = false;
      this.form.submit();
    }

    return false;
  }

  onUploadedCallback() {
    let _nextInLine;
    // uploads next image. if we have one, and bumps it off the list
    if (_nextInLine = this.fileStore.items.shift())
      this.uploadItem(_nextInLine);
    // now the form will be submitted without hitting the uploads.
    else {
      this.block_form_submission = false;
      this.submit_buttons.forEach((element) => {
        element.value = this.localized_text.creating_observation_text;
      });
      this.form.submit();
    }
  }

  /*********************/
  /*   FileStoreItem   */
  /*********************/
  // This is the object itself.
  // When initializing, also loadAndDisplayItem(item)
  FileStoreItem(file_or_url, uuid) {
    const item = {};

    if (typeof file_or_url == "string") {
      item.is_file = false;
      item.url = file_or_url;
      item.file_name = decodeURI(file_or_url.replace(/.*\//, ""));
      item.file_size = 0;
    } else {
      item.is_file = true;
      item.file = file_or_url;
      item.file_name = file_or_url.name;
      item.file_size = file_or_url.size;
    }
    item.uuid = uuid;
    item.dom_element = null;
    item.exif_data = null;
    item.processed = false; // check the async status of files

    return item;
  }

  // Do a fetch request to get the template, populate it with the item data,
  // then get EXIF data, and read the file with FileReader.
  loadAndDisplayItem(item) {
    const url = this.get_template_uri + "?img_number=" + item.uuid;

    fetch(url).then((response) => {
      if (response.ok) {
        if (200 <= response.status && response.status <= 299) {
          response.text().then((html) => {
            // the text returned is the raw HTML template
            this.addTemplateToPage(item, html)
            // extract the EXIF data (async) and then load it
            this.getExifData(item);
            // uses FileReader to load image as base64 async
            this.fileReadImage(item);
          }).catch((error) => {
            console.error("no_content:", error);
          });
        } else {
          console.log(`got a ${response.status}`);
        }
      }
    }).catch((error) => {
      console.error("Server Error:", error);
    });
  }

  addTemplateToPage(item, html) {
    html = html.replace(/\s\s+/g, ' ').replace(/[\n\r]/.gm, '')
      .replace('{{img_file_name}}', item.file_name)
      .replace('{{img_file_size}}', item.is_file ?
        Math.floor((item.file_size / 1024)) + "kb" : "").trim();

    // Create the DOM element and add it to FileStoreItem;
    // This should work if the html is valid!
    const template = document.createElement('template');
    template.innerHTML = html;

    // Hard to find without dev tools, but this is where the goods are:
    item.dom_element = template.content.childNodes[0];
    // Give it a blank dataset
    item.dom_element.dataset.geocode = "";

    if (item.file_size > this.max_image_size)
      item.dom_element.querySelector('.warn-text').innerText =
        this.localized_text.image_too_big_text;

    // add it to the page
    this.addedImagesTarget.append(item.dom_element);
    // scroll to it
    window.scrollTo({
      top: this.addedImagesTarget.offsetTop,
      behavior: 'smooth',
    });

    // bind the removeItem function.
    // can't be called from outside because it's about the FileStore item
    item.dom_element.querySelector('.remove_image_link')
      .onclick = () => {
        this.removeItem(item);
        this.refreshImageMessages();
        this.refreshGeocodeMessages();
      };

    // Has to be, because the select has a different controller
    item.dom_element.querySelector('select')
      .onchange = () => {
        this.refreshImageMessages();
      };

    // Need to also bind to year input
    item.dom_element.querySelector("[id$=_1i]")
      .onchange = () => {
        this.refreshImageMessages();
      };
  }

  fileReadImage(item) {
    if (item.is_file) {
      const fileReader = new FileReader();

      fileReader.onload = (fileLoadedEvent) => {
        // find the actual image element
        const _img = item.dom_element.querySelector('.img-responsive');
        // get image element in container and set the src to base64 img url
        _img.setAttribute('src', fileLoadedEvent.target.result);
      };

      fileReader.readAsDataURL(item.file);
    } else {
      const _img = item.dom_element.querySelector('.img-responsive');
      _img.setAttribute('src', item.url)
        .onerror = () => {
          alert("Couldn't read image from: " + item.url);
          this.removeItem(item);
        };
    }
  }

  // extracts the exif data async;
  getExifData(item) {
    const _image = item.dom_element.querySelector('.img-responsive');

    _image.onload = async () => {
      item.exif_data = await ExifReader.load(_image.src);
      this.applyExifData(item);
    };
  }

  // applies exif data to the DOM element, must already be attached
  applyExifData(item) {
    const _exif = item.exif_data,
      _camera_date = item.dom_element.querySelector(".camera_date_text");

    _camera_date.dataset.found = 'false';

    if (item.dom_element == null) {
      console.warn("Error: DOM element for this file has not been created, so cannot update it with exif data!");
      return;
    }

    item.dom_element.dataset.initialized = "true"

    // Geocode Logic
    // check if there is geodata on the image
    if (_exif.GPSLatitude && _exif.GPSLongitude) {
      const latLngAlt = this.getLatLongEXIF(_exif);
      debugger;
      // Set item's data-geocode attribute so we can have a record
      item.dom_element.dataset.geocode = JSON.stringify(latLngAlt)
    }

    // Image Date Logic
    if (_exif.DateTimeOriginal) {
      // we found the date taken, let's parse it down.
      // returns an array of [YYYY,MM,DD]
      const _date_taken_array =
        _exif.DateTimeOriginal.description.substring(' ', 10).
          split(':').reverse(),
        _exifSimpleDate = this.SimpleDate(..._date_taken_array);

      this.imageDate(item, _exifSimpleDate);

      // shows the exif date by the photo
      _camera_date.innerText = this.simpleDateAsString(_exifSimpleDate);
      _camera_date.dataset.found = "true";
      _camera_date.dataset.exif_date = _exifSimpleDate;
      // bind _camera_date so it will set the image date if clicked
      _camera_date.onclick = () => {
        this.imageDate(item, _exifSimpleDate);
        this.refreshImageMessages();
      }
    }
    // no date was found in EXIF data
    else {
      // Use observation date
      this.imageDate(item, this.observationDate());
    }

    item.processed = true;
  }

  // Maybe add a radio button option to set obs gps to this item's gps.
  // Or, if there are no more images with that location, remove the option.
  // Or, remove the whole gps_messages box.
  refreshGeocodeMessages() {
    const _geoOptions = this.gpsRadiosTarget;
    let _currentOptions = _geoOptions.querySelectorAll('input[type="radio"]');

    if (this.fileStore.items.length > 0) {
      let itemsHadGeocode = false;
      // We're comparing items in the FileStore against existing gps options.
      this.fileStore.items.forEach((item) => {
        let itemData = item.dom_element.dataset;
        if (itemData && itemData.geocode) {
          const itemGeocode = JSON.parse(item.dom_element.dataset.geocode)
          let _addGeoRadio = true;
          itemsHadGeocode = true;

          // check all current radio buttons
          if (_currentOptions.length > 0) {
            _currentOptions.forEach((element) => {
              const _existingGeocode = JSON.parse(element.dataset.geocode);
              const _latDif = Math.abs(itemGeocode.latitude)
                - Math.abs(_existingGeocode.latitude);
              const _longDif = Math.abs(itemGeocode.longitude)
                - Math.abs(_existingGeocode.longitude);

              // don't add geocodes that are only slightly different
              if ((Math.abs(_latDif) < 0.0002) || Math.abs(_longDif) < 0.0002)
                _addGeoRadio = false;
            });
          }

          if (_addGeoRadio) {
            const _radioBtnToInsert = this.makeGeocodeRadioBtn(itemGeocode);
            this.gpsRadiosTarget.appendChild(_radioBtnToInsert);
          }
        }
      })

      // Clean up if there's no images with geocodes (approximates may linger)
      if (!itemsHadGeocode) {
        _geoOptions.querySelectorAll('input[type="radio"]')
          .forEach((elem) => { elem.closest('.radio').remove(); })
      }

      // now check buttons again
      _currentOptions = _geoOptions.querySelectorAll('input[type="radio"]');

      if (_currentOptions.length > 0) {
        this.show(this.gpsMessagesTarget);
      } else {
        this.hide(this.gpsMessagesTarget);
      }
    }
  }

  // gets or sets image date
  imageDate(item, simpleDate) {
    const _img_day_select = item.dom_element.querySelector('[id$="_when_3i"]'),
      _img_month_select = item.dom_element.querySelector('[id$="_when_2i"]'),
      _img_year_field = item.dom_element.querySelector('[id$="_when_1i"]');

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

  getUserEnteredInfo(item) {
    return {
      day: item.dom_element.querySelectorAll('select')[0].value,
      month: item.dom_element.querySelectorAll('select')[1].value,
      year: item.dom_element.querySelectorAll('input')[2].value,
      license: item.dom_element.querySelectorAll('select')[2].value,
      notes: item.dom_element.querySelectorAll('textarea')[0].value,
      copyright_holder: item.dom_element.querySelectorAll('input')[1].value
    };
  }

  asformData(item) {
    const _info = this.getUserEnteredInfo(item),
      _fd = new FormData();

    if (item.file_size > this.max_image_size)
      return null;

    if (item.is_file)
      _fd.append("image[upload]", item.file, item.file_name);
    else
      _fd.append("image[url]", item.url);
    _fd.append("image[when][3i]", _info.day);
    _fd.append("image[when][2i]", _info.month);
    _fd.append("image[when][1i]", _info.year);
    _fd.append("image[notes]", _info.notes);
    _fd.append("image[copyright_holder]", _info.copyright_holder);
    _fd.append("image[license]", _info.license);
    _fd.append("image[original_name]", item.file_name);
    return _fd;
  }

  // upload with readable stream not implemented yet for fetch
  // https://stackoverflow.com/questions/35711724/upload-progress-indicators-for-fetch
  // https://developer.mozilla.org/en-US/docs/Web/API/Streams_API/Using_readable_streams
  // https://developer.mozilla.org/en-US/docs/Web/API/ReadableStream
  uploadItem(item) {
    this.submit_buttons.forEach((element) => {
      element.value = this.localized_text.uploading_text + '...';
    });

    // const csrfToken = document.querySelector("[name='csrf-token']").content;
    const _formData = this.asformData(item);
    fetch(this.upload_image_uri, {
      method: 'POST', body: _formData
    }).then((response) => {
      if (response.ok) {
        if (200 <= response.status && response.status <= 299) {
          response.json().then((image) => {
            this.updateObsImages(item, image);
            this.hide(item.dom_element);
            this.onUploadedCallback();
          }).catch((error) => {
            console.error("no_image:", error);
          });
        } else {
          console.log(`got a ${response.status}`);
        }
      }
    }).catch((error) => {
      // console.error("Server Error:", error);
      alert(this.localized_text.something_went_wrong);
      this.onUploadedCallback();
    });
  }

  // async uploadItemAsync(item) {
  //   this.submit_buttons.forEach((element) => {
  //     element.value = this.localized_text.uploading_text + '...';
  //   });

  //   const _formData = this.asformData(item);
  //   let response = await fetch(this.upload_image_uri, {
  //     method: 'POST', body: _formData
  //   })
  //   let image = await response.json();

  //   this.updateObsImages(item, image);
  //   this.hide(item.dom_element);
  //   this.onUploadedCallback();
  // }

  // add the image to `good_images` and maybe set the thumb_image_id
  updateObsImages(item, image) {
    // #good_images is a hidden field
    const _good_image_vals = this.goodImagesTarget.value || "";
    const _radio = item.dom_element.querySelector(
      'input[name="observation[thumb_image_id]"]'
    )

    // add id to the good images form field.
    this.goodImagesTarget.value = [_good_image_vals, image.id].join(' ').trim();

    // set the hidden thumb_image_id field if the item's radio is checked
    if (_radio.checked) {
      _radio.value = image.id; // it's grabbing the val from the radio
      this.thumbImageIdTarget.value = image.id; // does not matter!
    }
  }

  removeItem(item) {
    // remove element from the dom;
    item.dom_element.remove();

    // remove the file from the dictionary
    if (item.is_file)
      delete this.fileStore.index[this.file_size];
    else
      delete this.fileStore.index[this.url];

    // remove item from items
    const idx = this.fileStore.items.indexOf(item);
    if (idx > -1)
      this.fileStore.items.splice(idx, 1);
  }

  /*********************/
  /*    DateUpdater    */
  /*********************/
  // Deals with synchronizing image and observation dates through
  // a message box presenting radio buttons. Pick image date or obs date.

  // will check differences between the image dates and observation dates
  areDatesInconsistent() {
    const _obsDate = this.observationDate(),
      _distinctDates = this.getDistinctImageDates();

    for (let i = 0; i < _distinctDates.length; i++) {
      if (!this.simpleDatesAreEqual(_distinctDates[i], _obsDate))
        return true;
    }
    return false;
  }

  refreshImageMessages() {
    const _distinctImgDates = this.getDistinctImageDates(),
      _obsDate = this.observationDate();

    this.imgDateRadiosTarget.innerHTML = '';
    this.obsDateRadiosTarget.innerHTML = '';
    this.makeObservationDateRadio(_obsDate);

    _distinctImgDates.forEach((simpleDate) => {
      if (!this.simpleDatesAreEqual(_obsDate, simpleDate))
        this.makeImageDateRadio(simpleDate);
    });

    if (this.areDatesInconsistent()) {
      this.show(this.imgMessagesTarget);
    } else {
      this.hide(this.imgMessagesTarget);
    }
  }

  reconcileDates(simpleDate, target) {
    if (target == "image")
      this.updateImageDates(simpleDate);
    if (target == "observation")
      this.observationDate(simpleDate);
    this.hide(this.imgMessagesTarget);
  }

  makeImageDateRadio(simpleDate) {
    const _date = JSON.stringify(simpleDate),
      _date_string = this.simpleDateAsString(simpleDate),
      _html = document.createElement('div');

    _html.classList.add("radio");
    _html.innerHTML = "<label><input type='radio' data-target='observation' data-date='" + _date + "' name='fix_date'/>" + _date_string + "</label>"

    this.imgDateRadiosTarget.appendChild(_html);
  }

  makeObservationDateRadio(simpleDate) {
    const _date = JSON.stringify(simpleDate),
      _date_string = this.simpleDateAsString(simpleDate),
      _html = document.createElement('div');

    _html.classList.add("radio");
    _html.innerHTML = "<label><input type='radio' data-target='image' data-date='" + _date + "' name='fix_date'/><span>" + _date_string + "</span></label>";

    this.obsDateRadiosTarget.appendChild(_html);
  }

  updateObservationDateRadio() {
    // _currentObsDate is an instance of this.SimpleDate(values)
    const _currentObsDate = this.observationDate();

    this.obsDateRadiosTarget.querySelectorAll('input')
      .forEach((elem) => { elem.dataset.date = _currentObsDate; })

    this.obsDateRadiosTarget.querySelectorAll('span')
      .forEach((elem) => {
        elem.innerText = this.simpleDateAsString(_currentObsDate);
      })

    if (this.areDatesInconsistent())
      this.show(this.imgMessagesTarget);
  }

  // gets or sets current obs date, simpledate object updates date
  observationDate(simpleDate) {
    // hack - reset obs_year because the year-input controller may fire after
    // this connects, and obs_year (the select) will be an obsolete element.
    this.obs_year = document.getElementById('observation_when_1i');

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
    } else { // or get it
      return this.SimpleDate(
        this.obs_day.value, this.obs_month.value, this.obs_year.value
      )
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

  /*********************/
  /*      Helpers      */
  /*********************/

  // notice this is for block-level
  show(element) {
    if (element !== undefined) {
      element.style.display = 'block';
      element.classList.add('in');
    }
  }

  hide(element) {
    if (element !== undefined) {
      element.classList.remove('in');
      window.setTimeout(() => { element.style.display = 'none'; }, 600);
    }
  }

  generateUUID() {
    return 'xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
      const r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }

  simpleDateAsString(simpleDate) {
    const _months = this.localized_text.months.split(' ');

    return simpleDate.day + "-"
      + _months[simpleDate.month - 1]
      + "-" + simpleDate.year;
  }

  /** Geocode Helpers **/

  makeGeocodeRadioBtn(latLngAlt) {
    const _geocode_string = latLngAlt.latitude.toFixed(5) + ", "
      + latLngAlt.longitude.toFixed(5),
      _html = document.createElement('div'),
      _label = document.createElement('label'),
      _input = document.createElement('input'),
      _a = document.createElement('a');

    _input.type = 'radio';
    _input.name = 'fix_geocode';
    _input.dataset.geocode = JSON.stringify(latLngAlt);

    _label.appendChild(_input);
    _label.insertAdjacentText('beforeend', _geocode_string)

    // dataset is read-only. attributes must be assigned singly
    _a.href = '#geocode_map';
    _a.dataset.role = 'show_on_map';
    _a.dataset.geocode = JSON.stringify(latLngAlt);
    _a.dataset.observationImagesTarget = 'showOnMap';
    _a.dataset.action = 'obs-form-images#showGeocodeonMap';
    _a.dataset.observationImagesLatLngAltParam = JSON.stringify(latLngAlt)
    _a.classList.add('ml-3');
    _a.textContent = this.localized_text.show_on_map;

    _html.classList.add("radio");
    _html.appendChild(_label);
    _html.appendChild(_a);

    return _html;
  }

  getLatLongEXIF(exifObject) {
    let lat = exifObject.GPSLatitude.description;
    let long = exifObject.GPSLongitude.description;

    const alt = exifObject.GPSAltitude ? (exifObject.GPSAltitude.value[0]
      / exifObject.GPSAltitude.value[1]).toFixed(0) + " m" : "";

    // make sure you don't end up on the wrong side of the world
    long = exifObject.GPSLongitudeRef.value[0] == "W" ? long * -1 : long;
    lat = exifObject.GPSLatitudeRef.value[0] == "S" ? lat * -1 : lat;

    return {
      latitude: lat,
      longitude: long,
      altitude: alt
    }
  }

  // Create a map object and specify the DOM element for display.
  showGeocodeonMap({ params: { latLngAlt } }) {
    const _latLng = { lat: latLngAlt.latitude, lng: latLngAlt.longitude },
      _map_container = document.getElementById('geocode_map');

    _map_container.setAttribute('height', '250');

    // Issue: there should not be two google maps on the page.
    const _map = new google.maps.Map(_map_container, {
      center: _latLng,
      zoom: 12
    });

    new google.maps.Marker({
      map: _map,
      position: _latLng
    });
    debugger
  }
}
