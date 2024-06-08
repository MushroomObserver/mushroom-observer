import { Controller } from "@hotwired/stimulus"
import { get, post, put } from '@rails/request.js'
import ExifReader from 'exifreader';

// When the user selects images, our JS loads them into browser memory. Note
// that this takes a couple seconds, but it is NOT the upload step, even though
// it may seem like it to the user: we are just displaying the image thumbnail
// preview from memory, and offering form fields for the eventual Image record
// creation. But nothing of the image exists on our servers yet.

// On form submit, our JS blocks submission of the observation form, while it
// first uploads the images, creates image records, processes them, and
// transfers them. The images at the moment of creation do not have an
// Observation association yet. If any do not process, we sort the good from the
// bad and send them back to the JS ajax response, displaying the “good images”
// as created records (no longer editable) and giving the user a report on the
// “bad images”, offering a chance to add further images, or remove good
// images.

// If all images are processed without problems, the JS adds the list of created
// image IDs to the obs form, and programmatically submits the form without any
// further input from the user. The images are finally attached to the
// observation after it’s created, along with collection numbers, etc. But note
// that this create-obs step is all very quick. Even when image uploads have
// gone smoothly, the previous step above, image upload/process/transfer,
// accounts for ~75-95% of the time “creating the obs” that the user
// experiences.

const internalConfig = {
  // Make some of these targets for the controller
  block_form_submission: true,
  content: document.getElementById('content'),
  // TODO: replace this with two routes below
  get_template_uri: "/observations/images/uploads/new",
  // image_template_uri: "/observations/images/uploads/show",
  // image_form_uri: "/observations/images/uploads/new",
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

// This controller needs to be on the whole form, to enable the large drop area.
// (formerly "observation_images" section of the form)
// Connects to data-controller="obs-form-images"
export default class extends Controller {
  static targets = ["form", "carousel", "item", "thumbnail", "removeImg",
    "imageGpsMap", "goodImages", "thumbImageId", "setThumbImg", "isThumbImg",
    "thumbImgRadio", "obsThumbImgBtn"]

  initialize() {
  }

  connect() {
    this.element.dataset.stimulus = "connected";

    Object.assign(this, internalConfig);
    Object.assign(this.localized_text,
      JSON.parse(this.element.dataset.localization));

    // Doesn't seem reliably available from internalConfig.
    // this.form = document.forms.observation_form;
    this.form = this.element;
    this.drop_zone = this.formTarget;
    this.submit_buttons = this.element.querySelectorAll('input[type="submit"]');
    this.max_image_size = this.element.dataset.upload_max_size;

    this.fileStore = { items: [], index: {} }

    this.set_bindings();
  }

  // Doing this rather than stimulus actions on the form element, because there
  // are so many, and this gives finer-grain control (e.g. dragenter, below)
  set_bindings() {
    // make sure submit buttons are enabled when the dom is loaded
    this.submit_buttons.forEach((element) => {
      element.disabled = false;
    });

    // Drag and Drop bindings on the form
    this.drop_zone.addEventListener('dragover', (e) => {
      e.preventDefault();
      this.addDashedBorder();
      return false;
    });
    this.drop_zone.addEventListener('dragenter', (e) => {
      e.preventDefault();
      e.stopPropagation();
      this.addDashedBorder();
      return false;
    });
    this.drop_zone.addEventListener('dragleave', this.removeDashedBorder());

    // ADDING FILES
    this.drop_zone.addEventListener('drop', (e) => {
      this.dropFiles(e);
    });

    // Detect when a user submits observation; includes upload logic
    this.form.onsubmit = (event) => {
      if (this.block_form_submission) {
        this.uploadAll();
        return false;
      }
      return true;
    };
  }

  addDashedBorder() {
    // console.log("addDashedBorder")
    this.drop_zone.classList.add('dashed-border');
  }

  removeDashedBorder() {
    // console.log("removeDashedBorder")
    this.drop_zone.classList.remove('dashed-border');
  }

  dropFiles(e) {
    if (e.preventDefault) { e.preventDefault(); }
    this.removeDashedBorder();
    const dataTransfer = e.dataTransfer;
    if (dataTransfer.files.length > 0)
      this.addFiles(dataTransfer.files);
  }

  // Deactivate other radio buttons manually because they are not grouped (?)
  setObsThumbnail(event) {
    // event.target is the label.btn clicked to make whichever the default image
    // but could also be any descendant element
    const button = event.target.closest('.obs_thumb_img_btn'),
      radio = button.querySelector('input[type="radio"]');
    // reset selections
    this.obsThumbImgBtnTargets.forEach((elem) => {
      elem.classList.remove('active');
    });
    // reset the checked default thumbnail
    this.thumbImgRadioTargets.forEach((elem) => {
      elem.removeAttribute('checked');
    });

    // set selection...
    button.classList.add('active');
    button.querySelector(
      'input[type="radio"][name="observation[thumb_image_id]"]'
    ).setAttribute('checked', '');
    this.thumbImageIdTarget.setAttribute('value', radio.value);
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
      this.loadAndDisplayItem(_item, i);

      this.fileStore.items.push(_item)
    }
  }

  addUrl(url) {
    // check if the url is already in the fileStore
    if (this.fileStore.items.find((item) => item.url === url) == undefined) {
      const _item = this.FileStoreItem(url, this.generateUUID());
      this.loadAndDisplayItem(_item, 0);

      this.fileStore.items.push(_item);
    }
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
  // This is a temporary object representing the file.
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
    item.thumbnail_element = null;
    item.exif_data = null;
    item.processed = false; // check the async status of files

    return item;
  }

  // Use requestjs-rails to make fetch request to get the carousel-item template
  // with the image and its form, as well as the carousel-thumbnail template.
  // requestjs-rails automatically calls renderStreamMessage on the response, so
  // it's getting prepended by Turbo. We populate the element with file data
  // via itemTargetConnected. In order to manipulate the returned element
  // manually, we would have to use vanilla-JS `fetch` and prepend it to the
  // carousel ourselves.
  async loadAndDisplayItem(item, i) {
    const _file_size = item.is_file ?
      Math.floor((item.file_size / 1024)) + "kb" : "";
    const response = await get(this.get_template_uri,
      {
        contentType: "text/html",
        responseKind: "turbo-stream",
        query: {
          index: i,
          img_id: item.uuid,
          img_file_name: item.file_name,
          img_file_size: _file_size
        }
      });

    if (response.ok) {
      const html = await response.text
      if (html) {
        // handling it with itemTargetConnected callback
      }
    } else {
      console.log(`got a ${response.status}`);
    }
  }

  // Stimulus "target callback" on carousel item added.
  // When Turbo prepends the carousel item to the page, we need to
  // - re-sort the carousel
  // - populate the fileStore item with exifData
  // - populate the form with a few details about the file
  // - read the file with FileReader to display the image
  itemTargetConnected(itemElement) {
    // console.log("itemTargetConnected")
    // console.log(itemElement);
    if (itemElement.hasAttribute('data-good-image')) return;

    // this.addCarouselIndicator();
    this.sortCarousel();

    // Attach a reference to the dom element to the item object so we can
    // populate the item object as well as the element
    const item = this.findFileStoreItem(itemElement);
    item.dom_element = itemElement;
    item.dom_element.dataset.geocode = "";

    if (item.file_size > this.max_image_size)
      item.dom_element.querySelector('.warn-text').innerText =
        this.localized_text.image_too_big_text;

    // extract the EXIF data (async) and populate the item and element
    this.getExifData(item);
    // uses FileReader to load image as base64 async and set the img src
    this.setImgSrc(item, itemElement);
  }

  // Stimulus "target callback" on carousel item removed:
  // Remove the last indicator - they're only matched to items by index
  // Can't bind to targetDisconnected because there are two targets to remove.
  // itemTargetDisconnected(itemElement) {
  //   // this.removeCarouselIndicator();
  //   this.sortCarousel();
  // }

  thumbnailTargetConnected(thumbElement) {
    if (thumbElement.hasAttribute('data-good-image')) return;

    // Attach it to the FileStore item if there is one,
    const item = this.findFileStoreItem(thumbElement);
    item.thumbnail_element = thumbElement;
    this.setImgSrc(item, thumbElement);
  }

  // Add an indicator for the most recent element.
  // addCarouselIndicator() {
  //   const _html_id = this.carouselTarget.getAttribute('id'),
  //     _indicontrols = this.carouselTarget.querySelector('.carousel-indicators'),
  //     _indicators = this.carouselTarget.querySelectorAll('.carousel-indicator'),
  //     _new_indicator = document.createElement("li");

  //   _new_indicator.setAttribute('data-target', '#' + _html_id);
  //   _new_indicator.setAttribute('data-slide-to', 0);
  //   _new_indicator.classList.add('carousel-indicator');
  //   _new_indicator.classList.add('active');

  //   // Scoot the indicators over by one
  //   if (_indicators.length > 0) {
  //     _indicators.forEach((indicator) => {
  //       const _ref = Number(indicator.dataset.slideTo);
  //       indicator.setAttribute('data-slide-to', _ref + 1);
  //     });
  //   }
  //   _indicontrols.prepend(_new_indicator);
  // }

  // removeCarouselIndicator() {
  //   const _indicators =
  //     this.carouselTarget.querySelectorAll('.carousel-indicator'),
  //     _count = _indicators.length;

  //   // _count >= 1 should be the case, but just in case they're not in sync:
  //   // Remove the last indicator.
  //   if (_count >= 1) { _indicators[_count - 1].remove(); }
  // }

  // Adjust the carousel controls and indicators for the new/removed item.
  // Can't bind to targetDisconnected because there are two targets to remove.
  sortCarousel() {
    const _items = this.carouselTarget.querySelectorAll('.item'),
      _indicators = this.carouselTarget.querySelectorAll('.carousel-indicator'),
      _active = this.carouselTarget.querySelectorAll('.active');

    // Remove all active classes from items and indicators
    _active.forEach((elem) => { elem.classList.remove('active') });

    // This always makes the new (or first) element in the carousel active.
    _items[0]?.classList?.add('active');
    _indicators[0]?.classList?.add('active');

    this.sortCarouselControls();
  }

  // Show or hide the controls, depending on the total.
  sortCarouselControls() {
    const _items = this.carouselTarget.querySelectorAll('.item'),
      _indicontrols = this.carouselTarget.querySelector('.carousel-indicators'),
      _controls = this.carouselTarget.querySelector('.carousel-control'),
      _count = _items.length;

    if (_count > 1) {
      _indicontrols.classList.remove('d-none');
      _controls.classList.remove('d-none');
    } else {
      _indicontrols.classList.add('d-none');
      _controls.classList.add('d-none');
    }
  }

  // This is for removing an image that hasn't been uploaded yet.
  // Carousel gets sorted out separately by the itemTargetDisconnected callback.
  removeClickedItem(event) {
    const _item = this.findFileStoreItem(event.target);
    this.removeItem(_item);
  }

  // This is for detaching an image already attached to the observation.
  // (not a fileStore item), on the obs edit form. It just removes the item
  // from the carousel and id from "good_images". Has no effect until submit.
  removeAttachedItem(event) {
    const _good_images = this.goodImagesTarget.value,
      _good_image_vals = _good_images.split(" "),
      _image_id = event.target.dataset.imageId,
      _thumb_id = this.thumbImageIdTarget.value;

    const _new = _good_image_vals.filter(item => item !== _image_id).join(" ");
    this.goodImagesTarget.value = _new;

    if (_thumb_id == _image_id) {
      this.thumbImageIdTarget.value = "";
    }
    document.getElementById("carousel_item_" + _image_id).remove();
    document.getElementById("carousel_thumbnail_" + _image_id).remove();

    // Re-sort the carousel
    this.sortCarousel();
  }

  // "closest" works even if the element is the item itself.
  findFileStoreItem(element) {
    const _identifiable = element.closest(".item") ??
      element.closest(".carousel-indicator");

    return this.fileStore.items.find(
      (item) => item.uuid === _identifiable?.dataset?.imageUuid
    );
  }

  // This gives the img src a base64 string, or the url.
  // In most cases it's the base64, which is as long as the file.
  // That's why we can't send the src attribute to the template call
  // to get a complete layout; it has to be added by JS.
  setImgSrc(item, element) {
    // find the image element in carousel-item
    const _img = element.querySelector('.set-src');

    if (item.is_file) {
      const fileReader = new FileReader();

      fileReader.onload = (fileLoadedEvent) => {
        // set the src to base64 img url
        _img.setAttribute('src', fileLoadedEvent.target.result);
      };

      fileReader.readAsDataURL(item.file);
    } else {
      _img.setAttribute('src', item.url)
        .onerror = () => {
          alert("Couldn't read image from: " + item.url);
          this.removeItem(item);
        };
    }
  }

  // maybe stimulus action on image?
  // extracts the exif data async;
  getExifData(item) {
    const _image = item.dom_element.querySelector('.carousel-image');

    _image.onload = async () => {
      item.exif_data = await ExifReader.load(_image.src);
      this.applyExifData(item);
    };
  }

  // applies exif data to the DOM element, must already be attached
  applyExifData(item) {
    const _exif = item.exif_data;

    if (item.dom_element == null) {
      console.warn("Error: DOM element for this file has not been created, so cannot update it with exif data!");
      return;
    }

    item.dom_element.dataset.initialized = "true"

    this.applyExifGPS(item, _exif);
    this.applyExifDate(item, _exif);

    item.processed = true;

    // If this is the first one, transfer the exif data to the obs fields
    // and set a flag so we don't do it again. Here because it's async.
    if (this.element.dataset?.exifUsed !== "true" &&
      item.dom_element.dataset?.geocode !== "") {
      this.transferExifToObsFields(item.dom_element);
      this.element.dataset.exifUsed = "true";
    }
  }

  applyExifGPS(item, _exif) {
    const _exif_lat = item.dom_element.querySelector(".exif_lat"),
      _exif_lng = item.dom_element.querySelector(".exif_lng"),
      _exif_alt = item.dom_element.querySelector(".exif_alt");

    // Geocode Logic
    // check if there is geodata on the image
    if (_exif.GPSLatitude && _exif.GPSLongitude) {
      const latLngAlt = this.getLatLngEXIF(_exif);

      // Set item's data-geocode attribute so we can have a record
      item.dom_element.dataset.geocode = JSON.stringify(latLngAlt);

      _exif_lat.innerText = latLngAlt.lat.toFixed(5);
      _exif_lng.innerText = latLngAlt.lng.toFixed(5);
      _exif_alt.innerText = latLngAlt.alt;
    }
  }

  applyExifDate(item, _exif) {
    const _exif_date = item.dom_element.querySelector(".exif_date");
    _exif_date.dataset.found = 'false';

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
      item.dom_element.dataset.exif_date = JSON.stringify(_exifSimpleDate);
      _exif_date.innerText = this.simpleDateAsString(_exifSimpleDate);
      _exif_date.dataset.found = "true";
    }
    // no date was found in EXIF data
    else {
      // Use observation date
      this.imageDate(item, this.observationDate());
    }
  }

  // Click callback so .exif_date will set the image date if clicked
  exifToImageDate(event) {
    const _item = this.findFileStoreItem(event.target),
      _exifSimpleDate = JSON.parse(_item.dom_element.dataset.exif_date);

    this.imageDate(_item, _exifSimpleDate);
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

  // Click callback for transfer, disabling this button but enabling others.
  // Kind of like radio
  selectExifButton(selector, element) {
    // enable all the buttons
    this.carouselTarget.querySelectorAll(selector).forEach((element) => {
      element.removeAttribute('disabled');
    });
    // disable the button that was clicked, which may change the text
    element.closest('.btn').setAttribute('disabled', 'disabled');
  }

  geocodesDiffer(first, second) {
    return Math.abs(first.lat - second.lat) >= 0.0002
      || Math.abs(first.lng - second.lng) >= 0.0002;
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

  // This is too brittle. Selectors needed.
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

  // Because it can't be a form (within a form), we build formData manually.
  asFormData(item) {
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

  // This essentially submits a "form" for each image. But there can't
  // currently be a form element, because the image fields are nested inside
  // the obs form. So we turn the fields into a FormData object with JS.
  async uploadItem(item) {
    // It would be nice to do a progress bar, but as of now, upload with
    // readable stream is not implemented yet for fetch in the browser spec.
    // https://stackoverflow.com/questions/35711724/upload-progress-indicators-for-fetch
    // https://developer.mozilla.org/en-US/docs/Web/API/Streams_API/Using_readable_streams
    // https://developer.mozilla.org/en-US/docs/Web/API/ReadableStream
    this.submit_buttons.forEach((element) => {
      element.value = this.localized_text.uploading_text + '...';
    });

    const _formData = this.asFormData(item);
    const response = await post(this.upload_image_uri,
      { body: _formData, responseKind: "json" });

    // Note: It never hits any of the below, even with multiple images (!)
    // The controller action at upload_image_uri is uploading the images, and
    // it's already submitting the form and leaving the page.
    // Maybe because this is async? Anyway, it seems to work.
    // updateObsImages is never called, nor onUploadedCallback.
    if (response.ok) {
      const image = await response.json
      if (image) {
        this.updateObsImages(item, image);
        this.hide(item.dom_element);
        this.onUploadedCallback();
      }
    } else {
      console.log(`got a ${response.status}`);
    }
  }

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
    item.thumbnail_element.remove();

    // remove item from items
    const idx = this.fileStore.items.indexOf(item);
    if (idx > -1)
      this.fileStore.items.splice(idx, 1);

    // Re-sort the carousel
    this.sortCarousel();
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
  showGeocodeonMap({ params: { latLngAlt } }) {
    const _latLng = { lat: latLngAlt.lat, lng: latLngAlt.lng },
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
  }
}
