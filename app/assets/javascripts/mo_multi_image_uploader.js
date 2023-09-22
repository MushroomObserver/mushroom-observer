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

    this.fileStore = { items: [], index: {} }

    // function of the Uploader instance, not the constructor
    this.set_bindings();
  }

  set_bindings() {
    // make sure submit buttons are enabled when the dom is loaded!
    this.submit_buttons.forEach((element) => {
      element.setAttribute('disabled', false);
    });

    // was bind('click.setGeoCodeBind'
    this.set_geocode_btn.onclick = () => {
      const _selectedItemData =
        document.querySelector('input[name=fix_geocode]:checked').dataset;

      if (_selectedItemData) {
        document.getElementById('observation_lat').value =
          _selectedItemData.geocode.latitude;
        document.getElementById('observation_long').value =
          _selectedItemData.geocode.longitude;
        document.getElementById('observation_alt').value =
          _selectedItemData.geocode.altitude;
        this.hide(this.geocode_messages);
      }
    };

    this.ignore_geocode_btn.onclick = () => {
      this.hide(this.geocode_messages);
    };

    document.body.querySelectorAll('[data-role="show_on_map"]')
      .forEach((elem) => {
        elem.onclick = () => {
          this.showGeocodeonMap(this.dataset.geocode);
        }
      })

    // was bind('click.fixDateBind
    this.fix_date_submit.onclick = () => {
      const _selectedItemData =
        document.querySelector('input[name=fix_date]:checked').dataset;

      if (_selectedItemData && _selectedItemData.date) {
        this.fixDates(
          _selectedItemData.date, _selectedItemData.target
        );
      }
    };

    // was bind('click.ignoreDateBind'
    this.ignore_date_submit.onclick = () => {
      this.hide(this.img_messages);
    };

    this.obs_year.onchange = () => {
      this.updateObservationDateRadio()
    };
    this.obs_month.onchange = () => {
      this.updateObservationDateRadio()
    };
    this.obs_day.onchange = () => {
      this.updateObservationDateRadio()
    };

    // Drag and Drop bindings on the window

    // ['dragover', 'dragenter'].forEach((e) => {
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
    // })

    // ['dragend', 'dragleave', 'dragexit'].forEach((e) => {
    //   this.content.addEventListener(e, function (e) {
    //     removeDashedBorder();
    //   });
    // })
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

      const dataTransfer = e.originalEvent.dataTransfer;
      if (dataTransfer.files.length > 0)
        this.addFiles(dataTransfer.files);
      // There are issues to work out concerning dragging and dropping
      // images from other websites into the observation form.
      // else
      //   fileStore.addUrl(dataTransfer.getData('Text'));
    };

    // Detect when files are added from browser
    this.select_files_button.onchange = (event) => {
      // Get the files from the browser
      const files = event.target.files;
      this.addFiles(files);
    };

    // IMPORTANT: This allows the user to update the thumbnail on the edit
    // observation view.
    document
      .querySelectorAll('[type="radio"][name="observation[thumb_image_id]"]')
      .forEach((elem) => {
        elem.onchange = function () {
          document.getElementById('observation_thumb_image_id')
            .value = this.value;
        }
      })

    // Logic for setting the default thumbnail
    document.body
      .querySelectorAll('[data-role="set_as_default_thumbnail"]')
      .forEach((elem) => {
        elem.onclick = function (event) {
          // `this` is the link clicked to make default image
          event.preventDefault();

          // reset selections
          // remove hidden from the links
          document.querySelectorAll('[data-role="set_as_default_thumbnail"]')
            .forEach((elem) => {
              elem.classList.remove('hidden');
            })
          // add hidden to the default thumbnail text
          document.querySelectorAll('.is_default_thumbnail')
            .forEach((elem) => {
              elem.classList.add('hidden');
            })
          // reset the checked default thumbnail
          document.querySelectorAll(
            'input[type="radio"][name="observation[thumb_image_id]"]'
          ).forEach((elem) => {
            elem.setAttribute('checked', false);
          })

          // set selections
          // add hidden to the link clicked
          this.classList.add('hidden');
          // show that the image is default
          const siblings = _this.parentNode.childNodes

          siblings.querySelectorAll('.is_default_thumbnail').forEach((elem) => {
            elem.classList.remove('hidden');
          })
          // adjust hidden radio button to select default thumbnail
          siblings.querySelectorAll(
            'input[type="radio"][name="observation[thumb_image_id]"]'
          ).forEach((elem) => {
            elem.setAttribute('checked', true);
          })
        }
      })

    // Detect when a user submits observation; includes upload logic
    this.form.onsubmit = (event) => {
      // event.preventDefault();
      if (this.block_form_submission) {
        this.uploadAll();
        return false;
      }
      return true;
    };
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
    // loop through attached files, make sure we aren't adding duplicates
    for (let i = 0; i < files.length; i++) {
      // stop adding the file, one with this exact size is already attached
      // TODO: What are the odds of this?
      if (this.fileStore.index[files[i].size] != undefined) {
        continue;
      }

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
        this.refreshBox();
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
    this.fileStore.items.forEach(function (item) {
      this.imageDate(item, simpleDate);
    });
  }

  getDistinctImageDates() {
    const _testAgainst = "",
      _distinct = [];

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

  // remove all the images as they were uploaded!
  destroyAll() {
    // or maybe bump the item from the fileStore.items? indexOf and splice
    this.fileStore.items.forEach((item) => { item.destroy() });
  }

  uploadAll() {
    // disable submit and remove image buttons during upload process.
    this.submit_buttons.forEach(
      (element) => { element.setAttribute('disabled', 'true') }
    );
    // Note that remove image links are not present at initialization
    document.querySelectorAll(".remove_image_link").forEach((elem) => {
      this.hide(elem);
    });

    // const _firstUpload = this.fileStore.items[0];
    let item;

    // uploads first image. if we have one, and bumps it off the list
    if (item = this.fileStore.items.shift()) {
      this.uploadItem(item, this.onUploadedCallback());
    } else {
      // no images to upload, submit form
      this.block_form_submission = false;
      this.form.submit();
    }

    return false;
  }

  // callback function to move through the the images to upload
  // getNextImage() {
  //   this.fileStore.items.shift();
  //   return this.fileStore.items[0];
  // }

  onUploadedCallback() {
    // const _nextInLine = this.getNextImage();
    let item;

    // uploads next image. if we have one, and bumps it off the list
    if (item = this.fileStore.items.shift())
      this.uploadItem(_nextInLine, this.onUploadedCallback());
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
    // + new URLSearchParams({ img_number: this.uuid })
    // console.log(url);

    fetch(url).then((response) => {
      if (response.ok) {
        if (200 <= response.status && response.status <= 299) {
          response.text().then((html) => {
            // the data returned is the raw HTML template
            this.addTemplateToPage(item, html)
            // extract the EXIF data (async) and then load it
            this.getExifData(item);
            // uses FileReader to load image as base64 async
            this.fileReadImage(item);
          }).catch((error) => {
            console.error("no_content:", error);
          });
        } else {
          // this.ajax_request = null;
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

    if (item.file_size > this.max_image_size)
      item.dom_element.querySelector('.warn-text').text =
        this.localized_text.image_too_big_text;

    // add it to the page
    this.add_img_container.append(item.dom_element);

    // bind the destroy function
    item.dom_element.querySelector('.remove_image_link')
      .onclick = (event) => {
        // huh?
        event.target.destroy();
        this.refreshBox();
      };

    item.dom_element.querySelector('select')
      .onchange = () => {
        this.refreshBox();
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
        .onerror = (event) => {
          alert("Couldn't read image from: " + item.url);
          // or maybe bump the item from the fileStore.items? indexOf and splice
          event.target.destroy();
        };
    }
  }

  // extracts the exif data async;
  getExifData(item) {
    item.dom_element.querySelector('.img-responsive')
      .onload = () => {
        EXIF.getData(this, function () {
          item.exif_data = this.exifdata;
          // apply the data to the DOM
          item.applyExifData();
        });
      };
  }

  // applies exif data to the DOM element, must already be attached
  applyExifData(item) {
    let _exif_date_taken;
    const _exif = item.exif_data;

    if (item.dom_element == null) {
      console.warn("Error: DOM element for this file has not been created, so cannot update it with exif data!");
      return;
    }

    // Geocode Logic
    // check if there is geodata on the image
    if (_exif.GPSLatitude && _exif.GPSLongitude) {

      const latLngAlt = this.getLatLongEXIF(_exif),
        radioBtnToInsert = this.makeGeocodeRadioBtn(latLngAlt);

      if (geocode_radio_container
        .querySelectorAll('input[type="radio"]').length === 0) {
        this.show(this.geocode_messages);
        this.geocode_radio_container.append(radioBtnToInsert);
      }

      // don't add geocodes that are only slightly different
      else {
        const shouldAddGeocode = true;

        this.geocode_radio_container
          .querySelectorAll('input[type="radio"]').forEach((element) => {
            const _existingGeocode = element.dataset.geocode;
            const _latDif = Math.abs(latLngAlt.latitude)
              - Math.abs(_existingGeocode.latitude);
            const _longDif = Math.abs(latLngAlt.longitude)
              - Math.abs(_existingGeocode.longitude);

            if ((Math.abs(_latDif) < 0.0002) || Math.abs(_longDif) < 0.0002)
              shouldAddGeocode = false;
          });

        if (shouldAddGeocode)
          this.geocode_radio_container.append(radioBtnToInsert);
      }
    }

    // Image Date Logic
    _exif_date_taken = item.exif_data.DateTimeOriginal;

    if (_exif_date_taken) {
      // we found the date taken, let's parse it down.
      // returns an array of [YYYY,MM,DD]
      const _date_taken_array =
        _exif_date_taken.substring(' ', 10).split(':'),
        _exifSimpleDate = new SimpleDate(_date_taken_array.reverse());

      this.imageDate(item, _exifSimpleDate);

      const _camera_date = item.dom_element.find(".camera_date_text");
      // shows the exif date by the photo
      _camera_date.text = this.simpleDateAsString(_exifSimpleDate);
      _camera_date.dataset.exif_date = _exifSimpleDate;
      _camera_date.onclick = () => {
        this.imageDate(item, _exifSimpleDate);
        this.refreshBox();
      }
    }
    // no date was found in EXIF data
    else {
      // Use observation date
      this.imageDate(item, this.observationDate());
    }

    this.processed = true;
  }

  imageDate(item, simpleDate) {
    const _day = item.dom_element.querySelectorAll('select')[0],
      _month = item.dom_element.querySelectorAll('select')[1],
      _year = item.dom_element.querySelectorAll('input')[2];
    let _date_values;

    if (simpleDate) {
      _date_values = [
        _day.value = simpleDate.day,
        _month.value = simpleDate.month,
        _year.value = simpleDate.year
      ]
    }
    return new SimpleDate(_date_values);
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

  // incrementProgressBar(item, decimalPercentage) {
  //   const _container =
  //     item.dom_element.querySelector(".added_image_name_container"),
  //     // if we don't have percentage, just set it to 0 percent
  //     _percent_string = decimalPercentage ?
  //       parseInt(decimalPercentage * 100).toString() + "%" : "0%";

  //   if (!item.isUploading) {
  //     item.isUploading = true;
  //     _container.html =
  //       '<div class="col-xs-12" style="z-index: 1">'
  //       + '<strong class="progress-text">'
  //       + this.localized_text.uploading_text + '</strong></div>'
  //       + '<div class="progress-bar position-absolute" '
  //       + 'style="width: 0%; height: 1.5em; background: #51B973; '
  //       + 'z-index: 0;"></div>'

  //     let i = 1;
  //     while (i < 900) {
  //       setTimeout(() => {
  //         _container.querySelector(".progress-text").html =
  //           this.localized_text.uploading_text +
  //           this.dots[i % 3];
  //         ++i;
  //       }, 333)
  //     }
  //   } else {
  //     const _progress_bar = _container.querySelector(".progress-bar"),
  //       _animation = [
  //         { width: _progress_bar.width },
  //         { width: _percent_string }
  //       ],
  //       _timing = { duration: decimalPercentage == 1 ? 1000 : 1500 };

  //     _progress_bar.animate(_animation, _timing);

  //     // 1500: a little extra to patch over gap between sending request
  //     // for next progress update and actually receiving it, which occurs
  //     // after a second is up... but not after image is done, no more
  //     // progress updates required then.
  //   }
  // }

  // upload with readable stream not implemented yet for fetch
  // https://stackoverflow.com/questions/35711724/upload-progress-indicators-for-fetch
  // https://developer.mozilla.org/en-US/docs/Web/API/Streams_API/Using_readable_streams
  // https://developer.mozilla.org/en-US/docs/Web/API/ReadableStream
  uploadItemXHR(item) {
    const xhrReq = new XMLHttpRequest(),
      progress = null;
    // let update = null;

    this.submit_buttons.value = this.localized_text.uploading_text + '...';
    // this.incrementProgressBar();

    // after image has been created.
    xhrReq.onreadystatechange = () => {
      if (xhrReq.readyState == 4) {
        if (xhrReq.status == 200) {
          const _image = JSON.parse(xhrReq.response);
          this.updateObsImages(_image);
        } else if (xhrReq.response) {
          alert(xhrReq.response);
        } else {
          alert(this.localized_text.something_went_wrong);
        }

        if (progress)
          window.clearTimeout(progress);

        // this.incrementProgressBar(item, 1);
        this.hide(item.dom_element);

        this.onUploadedCallback();
      }
    };

    // Note: Add the event listeners before calling open() on the request.
    // debugger;
    xhrReq.open("POST", this.upload_image_uri, true);
    xhrReq.setRequestHeader("X-Progress-ID", this.uuid);
    const _fd = this.asformData(item); // Send the form
    if (_fd != null) {
      xhrReq.send(_fd);
    } else {
      alert(this.localized_text.something_went_wrong);
      this.onUploadedCallback();
    }
  }

  uploadItem(item) {
    this.submit_buttons.value = this.localized_text.uploading_text + '...';
    const _fd = this.asformData(item);

    fetch(url, {
      method: 'POST',
      // headers: {
      // 'X-CSRF-Token': csrfToken,
      // 'X-Requested-With': 'XMLHttpRequest',
      // 'Content-Type': 'application/json',
      // 'Accept': 'application/json'
      // },
      // credentials: 'same-origin',
      body: _fd
    }).then((response) => {
      if (response.ok) {
        if (200 <= response.status && response.status <= 299) {
          response.json().then((content) => {
            // debugger;
            const _image = content;
            this.updateObsImages(_image);
          }).catch((error) => {
            console.error("no_content:", error);
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

  // add the image to `good_images` and maybe set the thumb_image_id
  updateObsImages(item, _image) {
    // #good_images is a hidden field
    const _good_image_vals = this.good_images.value ?? "";

    // add id to the good images form field.
    this.good_images.value =
      [_good_image_vals, _image.id].join(' ').trim();

    // set the thumbnail if it is selected
    if (item.dom_element
      .querySelector('input[name="observation[thumb_image_id]"]')
      .checked) {
      document.getElementById('observation_thumb_image_id').value =
        _image.id;
    }
  }

  destroy(item) {
    // remove element from the dom;
    item.dom_element.remove();
    if (item.is_file)
      // remove the file from the dictionary
      delete this.fileStore.index[this.file_size()];
    else
      // remove the file from the dictionary
      delete this.fileStore.index[this.url];

    // removes the file from the array
    const idx = this.fileStore.items.indexOf(this);
    if (idx > -1)
      // removes the file from the array
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

  refreshBox() {
    const _distinctImgDates = this.getDistinctImageDates(),
      _obsDate = this.observationDate();

    this.img_radio_container.html = '';
    this.obs_radio_container.html = '';
    this.makeObservationDateRadio(_obsDate);

    _distinctImgDates.forEach((simpleDate) => {
      if (!this.simpleDatesAreEqual(_obsDate, simpleDate))
        this.makeImageDateRadio(simpleDate);
    });

    if (this.areDatesInconsistent()) {
      this.show(this.img_messages);
    } else {
      this.hide(this.img_messages);
    }
  }

  fixDates(simpleDate, target) {
    if (target == "image")
      this.updateImageDates(simpleDate);
    if (target == "observation")
      this.observationDate(simpleDate);
    this.hide(this.img_messages);
  }

  makeImageDateRadio(simpleDate) {
    const _date = JSON.stringify(simpleDate),
      _date_string = this.simpleDateAsString(simpleDate),
      _html = "<div class='radio'><label><input type='radio' data-target='observation' data-date='" + _date + "' name='fix_date'/>" + _date_string + "</label></div>"

    this.img_radio_container.append(_html);
  }

  makeObservationDateRadio(simpleDate) {
    const _date = JSON.stringify(simpleDate),
      _date_string = this.simpleDateAsString(simpleDate),
      _html = "<div class='radio'><label><input type='radio' data-target='image' data-date='" + _date + "' name='fix_date'/><span>" + _date_string + "</span></label></div>";

    this.obs_radio_container.append(_html);
  }

  updateObservationDateRadio() {
    // _currentObsDate is an instance of Uploader.SimpleDate(values)
    const _currentObsDate = this.observationDate();

    this.obs_radio_container.querySelectorAll('input')
      .forEach((elem) => { elem.dataset.date = _currentObsDate; })

    this.obs_radio_container.querySelectorAll('span')
      .forEach((elem) => {
        elem.text = this.simpleDateAsString(_currentObsDate);
      })

    if (this.areDatesInconsistent())
      this.show(this.img_messages);
  }

  // undefined gets current date, simpledate object updates date
  observationDate(simpleDate) {
    let _date_values;

    if (simpleDate && simpleDate.day && simpleDate.month &&
      simpleDate.year) {
      _date_values = [
        this.obs_day.value = simpleDate.day,
        this.obs_month.value = simpleDate.month,
        this.obs_year.value = simpleDate.year,
      ]
    }
    return new SimpleDate(_date_values);
  }

  /*********************/
  /* Simple Date Class */
  /*********************/

  SimpleDate(day, month, year) {
    this.day = parseInt(day);
    this.month = parseInt(month);
    this.year = parseInt(year);
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
    const geocode = JSON.stringify(latLngAlt),
      geocodeformap = JSON.stringify(latLngAlt),
      geoCodeStr = latLngAlt.latitude.toFixed(5) + ", "
        + latLngAlt.longitude.toFixed(5),

      html = "<div class='radio'><label><input type='radio' data-geocode='"
        + geocode + "' name='fix_geocode'/>" + geoCodeStr + "</label> "
        + "<a href='#geocode_map' data-role='show_on_map' class='ml-3' "
        + "data-geocode='" + geocodeformap + "'>"
        + this.localized_text.show_on_map + "</a></div>";

    return html;
  }

  getLatLongEXIF(exifObject) {
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

  showGeocodeonMap(latLngAlt) {
    // Create a map object and specify the DOM element for display.
    const _latLng = {
      lat: latLngAlt.latitude, lng: latLngAlt.longitude
    },
      _map_container = document.getElementById('geocode_map');

    _map_container.setAttribute('height', '250');

    const map = new google.maps.Map(_map_container, {
      center: _latLng,
      zoom: 12
    });

    const marker = new google.maps.Marker({
      map: map,
      position: obsLatLongFormat
    });
  }
}

