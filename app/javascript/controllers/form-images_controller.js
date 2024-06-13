import { Controller } from "@hotwired/stimulus"
import { get, post, put } from '@rails/request.js'

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
// Connects to data-controller="form-images"
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

  carouselTargetConnected() {
    this.sortCarousel();
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
      'input[type="radio"][name="thumb_image_id"]'
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

  // Callback for form-exif event "populated", fired from the carousel-item
  itemExifPopulated(event) {
    const _item = this.findFileStoreItem(event.target);
    _item.exif_populated = true;
  }

  areAllItemsExifPopulated() {
    this.fileStore.items.forEach((item) => {
      if (!item.exif_populated) return false;
    });
    return true;
  }

  addFiles(files) {
    // loop through attached FileList.
    // FileList is a peculiar object: { 0: File, 1: File, length: 2 }
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
    item.exif_populated = false; // check the async status of files
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
  // - read the file with FileReader to display the image
  itemTargetConnected(itemElement) {
    itemElement.dataset.stimulus = "connected";
    // console.log("itemTargetConnected")
    // console.log(itemElement);
    if (itemElement.hasAttribute('data-good-image')) return;

    this.sortCarousel();
    // Attach a reference to the dom element to the item object so we can
    // populate the item object as well as the element
    const item = this.findFileStoreItem(itemElement);
    item.dom_element = itemElement;

    if (item.file_size > this.max_image_size)
      itemElement.querySelector('.warn-text').innerText =
        this.localized_text.image_too_big_text;

    // uses FileReader to load image as base64 async and set the img src
    this.setImgSrc(item, itemElement);
  }

  thumbnailTargetConnected(thumbElement) {
    thumbElement.dataset.stimulus = "connected";
    if (thumbElement.hasAttribute('data-good-image')) return;

    // Attach it to the FileStore item if there is one,
    const item = this.findFileStoreItem(thumbElement);
    item.thumbnail_element = thumbElement;
    this.setImgSrc(item, thumbElement);
    this.sortCarousel();
  }

  // Adjust the carousel controls and indicators for the new/removed item.
  // Can't bind to targetDisconnected because there are two targets to remove.
  sortCarousel() {
    const _items = this.carouselTarget.querySelectorAll('.carousel-item'),
      _indicators = this.carouselTarget.querySelectorAll('.carousel-indicator'),
      _active = this.carouselTarget.querySelectorAll('.active');

    // Remove all active classes from items and indicators
    _active.forEach((elem) => { elem.classList.remove('active') });

    // This always makes the new (or first) element in the carousel active.
    _items[0]?.classList?.add('active');
    _indicators[0]?.classList?.add('active');

    this.showOrHideCarouselControls();
    this.resortCarouselIndicators(_items, _indicators);
  }

  // Show or hide the controls, depending on the total.
  showOrHideCarouselControls() {
    const _items = this.carouselTarget.querySelectorAll('.carousel-item'),
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

  // Required because thumbnails may load out of order of items.
  // This resorts based on the order of the items in the carousel, and sets
  // the slideTo attribute of the indicators to match the new order.
  resortCarouselIndicators(items, indicators) {
    // This could load on item or indicator, and one may be ahead of other.
    if (items.length == 0 || indicators.length == 0 ||
      items.length !== indicators.length) return;

    const _new_ordering = [],
      _indicontrols = this.carouselTarget.querySelector('.carousel-indicators');

    items.forEach((item, i) => {
      _new_ordering[i] =
        [...indicators].filter((indicator) => {
          return indicator.dataset.imageUuid == item.dataset.imageUuid
        })[0];
    });
    indicators.forEach((_indicator, i) => {
      _new_ordering[i].dataset.slideTo = i;
      _indicontrols.appendChild(_new_ordering[i]);
    });
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
    const _identifiable = element.closest(".carousel-item") ??
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

  // Get the info straight from the form inputs.
  getUserEnteredInfo(item) {
    const _elem = item.dom_element,
      day = _elem.querySelector('[id$="when_3i"]').value,
      month = _elem.querySelector('[id$="when_2i"]').value,
      year = _elem.querySelector('[id$="when_1i"]').value,
      license = _elem.querySelector('[id$="license_id"]').value,
      notes = _elem.querySelector('[id$="notes"]').value,
      copyright_holder = _elem.querySelector('[id$="copyright_holder"]').value;

    return { day, month, year, license, notes, copyright_holder };
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
      'input[type="radio"][name="thumb_image_id"]'
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
}
