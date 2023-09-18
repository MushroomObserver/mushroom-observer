//= require exif.js

class MOMultiImageUploader {

  constructor(localized_text = {}) {
    const localization_defaults = {
      uploading_text: "Uploading",
      image_too_big_text: "This image is too large. Image files must be less than 20Mb.",
      creating_observation_text: "Creating Observation...",
      months: "January, February, March, April, May, June, July, August, September, October, November, December",
      show_on_map: "Show on map",
      something_went_wrong: "Something went wrong while uploading image."
    }

    this.localized_text = localization_defaults.merge(localized_text);

    /*********************/
    /* Simple Date Class */
    /*********************/

    this.SimpleDate = class {
      constructor(day, month, year) {
        this.day = parseInt(day);
        this.month = parseInt(month);
        this.year = parseInt(year);

      }

      areEqual(simpleDate) { //returns true if same
        var _this = this;
        return _this.month == simpleDate.month && _this.day == simpleDate.day && _this.year == simpleDate.year;
      }

      asDateString() {
        var _months = localized_text.months.split(' ');
        return this.day + "-" + _months[this.month - 1] + "-" + this.year;
      }
    };

    /*********************/
    /*  DateUpdater  */
    /*********************/

    // Deals with synchronizing image and observation dates through
    // a message box.

    this.DateUpdater = class {
      constructor() { }

      areDatesInconsistent() {  //will check differences between the image dates and observation dates
        const _this = this,
          _obsDate = _this.observationDate(),
          _distinctDates = fileStore.getDistinctImageDates();

        for (let i = 0; i < _distinctDates.length; i++) {
          if (!_distinctDates[i].areEqual(_obsDate))
            return true;
        }

        return false;
      }

      refreshBox() {
        const _this = this,
          _distinctImgDates = fileStore.getDistinctImageDates(),
          obsDate = _this.observationDate();

        $imgRadioContainer.html('');
        $obsRadioContainer.html('');
        _this.makeObservationDateRadio(obsDate);

        _distinctImgDates.forEach(function (simpleDate) {
          if (!obsDate.areEqual(simpleDate))
            _this.makeImageDateRadio(simpleDate);
        });

        if (_this.areDatesInconsistent()) {
          $imgMessages.show('slow');
        } else {
          $imgMessages.hide('slow')
        }

      }

      fixDates = function (simpleDate, target) {
        const _this = this;
        if (target == "image")
          fileStore.updateImageDates(simpleDate);
        if (target == "observation")
          _this.observationDate(simpleDate);
        $imgMessages.hide('slow');
      }

      makeImageDateRadio(simpleDate) {
        const _this = this;

        var html = "<div class='radio'><label><input type='radio' data-target='observation' data-date='{{date}}' name='fix_date'/>{{dateStr}}</label></div>"
        html = html.replace('{{date}}', JSON.stringify(simpleDate));
        html = html.replace('{{dateStr}}', simpleDate.asDateString());
        $imgRadioContainer.append(jQuery(html));
      }

      makeObservationDateRadio(simpleDate) {
        const _this = this;

        let html = "<div class='radio'><label><input type='radio' data-target='image' data-date='{{date}}' name='fix_date'/><span>{{dateStr}}</span></label></div>";
        html = html.replace('{{date}}', JSON.stringify(simpleDate));
        html = html.replace('{{dateStr}}', simpleDate.asDateString());

        const $obsRadio = jQuery(html);
        $obsRadioContainer.append($obsRadio);
      }

      updateObservationDateRadio() {
        const _this = this;
        const _currentObsDate = _this.observationDate();
        $obsRadioContainer.find('input').data('date', _currentObsDate);
        $obsRadioContainer.find('span').text(_currentObsDate.asDateString());
        if (_this.areDatesInconsistent())
          $imgMessages.show('slow');
      }

      // undefined gets current date, simpledate object updates date
      observationDate = function (simpleDate) {

        if (simpleDate && simpleDate.day && simpleDate.month && simpleDate.year) {
          $obsDay.val(simpleDate.day);
          $obsMonth.val(simpleDate.month);
          $obsYear.val(simpleDate.year);
        }
        return new SimpleDate($obsDay.val(), $obsMonth.val(), $obsYear.val());
      }
    }

    /*********************/
    /*   FileStore   */
    /*********************/

    // Container for the image files.

    this.FileStore = class {
      constructor() {
        const _this = this;
        _this.fileStoreItems = [];
        _this.fileDictionary = {};
        _this.areAllProcessed = function () {
          for (let i = 0; i < _this.fileStoreItems.length; i++) {
            if (!_this.fileStoreItems[i].processed)
              return false;
          }
          return true;
        }
      }

      addFiles(files) {
        const _this = this;
        for (let i = 0; i < files.length; i++) { //loop through the attached files, check to make sure we aren't adding duplicates
          if (_this.fileDictionary[files[i].size] != undefined) {  //stop adding the file, an exact size is already attached  TODO:What are the odds of this?
            continue;  //stop here since a file with this size has been added.
          }

          const _fileStoreItem = new FileStoreItem(files[i], generateUUID()); //uuid is used as the index for the ruby form template.
          _this.fileDictionary[files[i].size] = _fileStoreItem;//add an item to the dictionary with the file size as they key
          _this.fileStoreItems.push(_fileStoreItem)
        }

        //check status of when all the selected files have processed.
        checkStatus();
        function checkStatus() {
          setTimeout(function () {
            if (!_this.areAllProcessed()) {
              checkStatus();
            }
            else {
              dateUpdater.refreshBox();
            }
          }, 30)
        }
      }

      addUrl(url) {
        const _this = this;
        if (_this.fileDictionary[url] == undefined) {
          const _fileStoreItem = new FileStoreItem(url, generateUUID());
          _this.fileDictionary[url] = _fileStoreItem;
          _this.fileStoreItems.push(_fileStoreItem);
        }
      }

      updateImageDates(simpleDate) {
        const _this = this;
        _this.fileStoreItems.forEach(function (fileStoreItem) {
          fileStoreItem.imageDate(simpleDate);
        });
      }

      getDistinctImageDates() {
        const _this = this,
          _testAgainst = "",
          _distinct = [];

        for (let i = 0; i < _this.fileStoreItems.length; i++) {
          const _ds = _this.fileStoreItems[i].imageDate().asDateString();
          if (_testAgainst.indexOf(_ds) != -1)
            continue;
          _testAgainst += _ds;
          _distinct.push(_this.fileStoreItems[i].imageDate())
        }

        return _distinct;
      }

      destroyAll() {
        this.fileStoreItems.forEach(function (item) {
          item.destroy();  //remove all the images as they were uploaded!
        });
      }

      uploadAll() {
        const _this = this;

        $submitButtons.prop('disabled', 'true'); //disable submit and remove image buttons during upload process.
        $removeLinks.hide();

        //callback function to move through the the images to upload
        function getNextImage() {
          _this.fileStoreItems[0].destroy();
          return _this.fileStoreItems[0];
        }

        function onUploadedCallback() {
          const nextInLine = getNextImage();
          if (nextInLine)
            nextInLine.upload(onUploadedCallback);
          else {
            blockFormSubmission = false; //now the form will be submitted without hitting the uploads.
            $submitButtons.val(localized_text.creating_observation_text);
            $form.submit();
          }
        }

        const firstUpload = _this.fileStoreItems[0];
        if (firstUpload) {
          firstUpload.upload(onUploadedCallback); //uploads first image. if we have one.
        }
        else {
          blockFormSubmission = false;
          $form.submit(); //no images to upload, submit form
        }

        return false;
      }
    }

    /*********************/
    /*   FileStoreItem   */
    /*********************/

    // Contains information about an image file.

    this.FileStoreItem = class {

      constructor(file_or_url, uuid) {
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
        this.processed = false;  //we use this to check the async status of files
        this.getTemplateHtml(); //kicks off the process of creating the image and such.
      }

      getTemplateHtml() {  //does an ajax request to get the template, then formats it, the format function adds to HTML.
        var _this = this;
        jQuery.get(_getTemplateUri, {
          img_number: _this.uuid
        }, function (data) {  //on success
          _this.createTemplate(data) //the data returned is the raw HTML template
          _this.getExifData();  //extract the EXIF data (async) and then load it
          _this.loadImage(); //load image as base64 async
        });
      }

      createTemplate(html_string) {
        var _this = this;

        html_string = html_string.replace('{{img_file_name}}', _this.file_name())
          .replace('{{img_file_size}}', this.is_file ? Math.floor((_this.file_size() / 1024)) + "kb" : "");

        _this.dom_element = $(html_string);  //Create the DOM element and add it to FileStoreItem;

        if (_this.file_size() > _maxImageSize)
          _this.dom_element.find('.warn-text').text(localized_text.image_too_big_text);

        $addedImagesContainer.append(_this.dom_element); //add it to the page

        _this.dom_element.find('.remove_image_link').on('click', function () {  // bind the destroy function
          _this.destroy();
          dateUpdater.refreshBox();
        });

        _this.dom_element.find('select').change(function () {
          dateUpdater.refreshBox();
        });

        // replace_date_select_with_text_field(jQuery(_this.dom_element.find('select')[2]));
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
        var _this = this;
        if (_this.is_file) {
          var fileReader = new FileReader();
          fileReader.onload = function (fileLoadedEvent) {
            var $img = _this.dom_element.find('.img-responsive').first(); //find the actual image element
            $img.attr('src', fileLoadedEvent.target.result); //get the image element in the container and set the src to base64 img url
          };
          fileReader.readAsDataURL(_this.file);
        } else {
          var $img = _this.dom_element.find('.img-responsive').first();
          $img.attr('src', _this.url).on('error', function () {
            alert("Couldn't read image from: " + _this.url);
            _this.destroy();
          });
        }
      }

      getExifData() {  //extracts the exif data async;
        var _fsItem = this;
        _fsItem.dom_element.find('.img-responsive').first().on('load', function () {
          EXIF.getData(this, function () {
            _fsItem.exif_data = this.exifdata;
            _fsItem.applyExifData();  //apply the data to the DOM
          });
        });
      }

      applyExifData() {  //applys exif data to the DOM element, DOM element must already be attached
        var _exif_date_taken,
          _this = this,
          _exif = this.exif_data;

        if (this.dom_element == null) {
          console.warn("Error: Dom element for this file has not been created, so cannot update it with exif data!");
          return;
        }


        //Geocode Logic

        if (_exif.GPSLatitude && _exif.GPSLongitude) { //check if there is geodata on the image

          var latLngObject = getLatitudeLongitudeFromEXIF(_exif),
            radioBtnToInsert = makeGeocodeRadioBtn(latLngObject);

          if ($geocodeRadioContainer.find('input[type="radio"]').length === 0) {
            $geocodeMessages.show('medium');
            $geocodeRadioContainer.append(radioBtnToInsert);
          }

          else {
            var shouldAddGeocode = true; //don't add geocodes that are only slightly different
            $geocodeRadioContainer.find('input[type="radio"]').each(function (index, element) {
              var existingGeocode = jQuery(element).data().geocode;
              var latDif = Math.abs(latLngObject.latitude) - Math.abs(existingGeocode.latitude);
              var longDif = Math.abs(latLngObject.longitude) - Math.abs(existingGeocode.longitude);

              if ((Math.abs(latDif) < 0.0002) || Math.abs(longDif) < 0.0002)
                shouldAddGeocode = false;
            });

            if (shouldAddGeocode)
              $geocodeRadioContainer.append(radioBtnToInsert);
          }
        }



        //Image Date Logic
        _exif_date_taken = _this.exif_data.DateTimeOriginal;
        if (_exif_date_taken) {
          //we found the date taken, let's parse it down.
          var _date_taken_array = _exif_date_taken.substring(' ', 10).split(':'), //returns an array of [YYYY,MM,DD]
            _exifSimpleDate = new SimpleDate(_date_taken_array[2], _date_taken_array[1], _date_taken_array[0]);
          _this.imageDate(_exifSimpleDate);

          var $camera_date = _this.dom_element.find(".camera_date_text");
          $camera_date.text(_exifSimpleDate.asDateString());//shows the exif date by the photo
          $camera_date.data('exif_date', _exifSimpleDate);
          $camera_date.on('click', function () {
            _this.imageDate(_exifSimpleDate);
            dateUpdater.refreshBox();
          })

        }
        else {  //no date was found in EXIF data
          _this.imageDate(dateUpdater.observationDate()); //Use observation date
        }
        _this.processed = true;
      }

      imageDate(simpleDate) {
        var _this = this,
          _$day = jQuery(_this.dom_element.find('select')[0]),
          _$month = jQuery(_this.dom_element.find('select')[1]),
          _$year = jQuery(_this.dom_element.find('input')[2]);
        if (simpleDate) {
          _$day.val(simpleDate.day);
          _$month.val(simpleDate.month);
          _$year.val(simpleDate.year);
        }
        return new SimpleDate(_$day.val(), _$month.val(), _$year.val());
      }

      getUserEnteredInfo() {
        return {
          day: jQuery(this.dom_element.find('select')[0]).val(),
          month: jQuery(this.dom_element.find('select')[1]).val(),
          year: jQuery(this.dom_element.find('input')[2]).val(),
          license: jQuery(this.dom_element.find('select')[2]).val(),
          notes: jQuery(this.dom_element.find('textarea')[0]).val(),
          copyright_holder: jQuery(this.dom_element.find('input')[1]).val()
        };
      }

      asFormData() {
        var _this = this,
          _info = _this.getUserEnteredInfo(),
          _fd = new FormData();

        if (_this.file_size() > _maxImageSize)
          return null;

        if (_this.is_file)
          _fd.append("image[upload]", _this.file, _this.file_name());
        else
          _fd.append("image[url]", _this.url);
        _fd.append("image[when][3i]", _info.day);
        _fd.append("image[when][2i]", _info.month);
        _fd.append("image[when][1i]", _info.year);
        _fd.append("image[notes]", _info.notes);
        _fd.append("image[copyright_holder]", _info.copyright_holder);
        _fd.append("image[license]", _info.license);
        _fd.append("image[original_name]", _this.file_name());
        return _fd;
      }

      incrementProgressBar(decimalPercentage) {
        var _this = this,
          _$container = _this.dom_element.find(".added_image_name_container"),
          _percent_string = decimalPercentage ? parseInt(decimalPercentage * 100).toString() + "%" : "0%"; //if we don't have percentage,  just set it to 0 percent

        if (!_this.isUploading) {
          _this.isUploading = true;
          _$container.html(
            '<div class="col-xs-12" style="z-index: 1"><strong class="progress-text">' + localized_text.uploading_text + '</strong></div>' +
            '<div class="progress-bar position-absolute" style="width: 0%; height: 1.5em; background: #51B973; z-index: 0;"></div>'
          )
          doDots(1);
        } else {
          _$container.find(".progress-bar").animate({ width: _percent_string }, decimalPercentage == 1 ? 1000 : 1500, "linear");
          // 1500: a little extra to patch over gap between sending request
          // for next progress update and actually receiving it, which occurs
          // after a second is up... but not after image is done, no more
          // progress updates required then.
        }

        function doDots(i) {
          setTimeout(function () {
            if (i < 900) {
              _$container.find(".progress-text").html(localized_text.uploading_text + _dots[i % 3]);
              doDots(++i);
            }
          }, 333)
        }
      }

      upload(onUploadedCallback) {
        var _this = this,
          xhrReq = new XMLHttpRequest(),
          progress = null,
          update = null;

        $submitButtons.val(localized_text.uploading_text + '...');
        _this.incrementProgressBar();

        xhrReq.onreadystatechange = function () { //after image has been created.
          if (xhrReq.readyState == 4) {
            if (xhrReq.status == 200) {
              var image = JSON.parse(xhrReq.response);
              goodImageVals = $goodImages.val() ? $goodImages.val() : "";
              $goodImages.val(goodImageVals.length == 0 ? image.id : goodImageVals + ' ' + image.id); //add id to the good images form field.
              if (_this.dom_element.find('input[name="observation[thumb_image_id]"]')[0].checked) {
                //set the thumbnail if it is selected
                jQuery('#observation_thumb_image_id').val(image.id);
              }
            } else if (xhrReq.response) {
              alert(xhrReq.response);
            } else {
              alert(localized_text.something_went_wrong);
            }
            if (progress) window.clearTimeout(progress);
            _this.incrementProgressBar(1);
            _this.dom_element.hide('slow');
            onUploadedCallback();
          }
        };

        // This is currently disabled in nginx, so no sense making the request.
        // update = function() {
        //   var req = new XMLHttpRequest();
        //   req.open("GET", _progressUri, 1);
        //   req.setRequestHeader("X-Progress-ID", _this.uuid);
        //   req.onreadystatechange = function () {
        //   if (req.readyState == 4 && req.status == 200) {
        //     var upload = eval(req.responseText);
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

        // Note: You need to add the event listeners before calling open()
        // on the request.
        xhrReq.open("POST", _uploadImageUri, true);
        xhrReq.setRequestHeader("X-Progress-ID", _this.uuid);
        var _fd = _this.asFormData(); //Send the form
        if (_fd != null) {
          xhrReq.send(_fd);
        } else {
          alert(localized_text.something_went_wrong);
          onUploadedCallback();
        }
      }

      destroy() {
        this.dom_element.remove();  //remove element from the dom;
        if (this.is_file)
          delete fileStore.fileDictionary[this.file_size()]; //remove the file from the dictionary
        else
          delete fileStore.fileDictionary[this.url]; //remove the file from the dictionary
        var idx = fileStore.fileStoreItems.indexOf(this); //removes the file from the array
        if (idx > -1)
          fileStore.fileStoreItems.splice(idx, 1);  //removes the file from the array
      }
    }

    // Internal Variable Definitions.
    const internals = {
      fileStore: new this.FileStore(),
      dateUpdater: new this.DateUpdater(),
      $addedImagesContainer: jQuery("#added_images_container"), // container to insert images into
      _maxImageSize: this.$addedImagesContainer.data("upload_max_size"),
      _getTemplateUri: "/ajax/multi_image_template",
      _uploadImageUri: "/ajax/create_image_object",
      _progressUri: "/ajax/upload_progress",
      _dots: [".", "..", "..."],
      blockFormSubmission: true,
      $form: jQuery(document.forms.namedItem("observation_form")),
      $submitButtons: $form.find('input[type="submit"]'),
      $goodImages: jQuery('#good_images'),
      $removeLinks: jQuery(".remove_image_link"),
      $selectFilesButton: jQuery('#multiple_images_button'),
      $obsDay: jQuery('#observation_when_3i'),
      $obsMonth: jQuery('#observation_when_2i'),
      $obsYear: jQuery('#observation_when_1i'),
      $imgRadioContainer: jQuery('#image_date_radio_container'),
      $obsRadioContainer: jQuery('#observation_date_radio_container'),
      $fixDateSubmit: jQuery('#fix_dates'),
      $ignoreDateSubmit: jQuery('#ignore_dates'),
      $imgMessages: jQuery("#image_messages"),
      $geocodeRadioContainer: jQuery('#geocode_radio_container'),
      $setGeocodeBtn: jQuery('#set_geocode'),
      $ignoreGeocodeBtn: jQuery('#ignore_geocode'),
      $geocodeMessages: jQuery('#geocode_messages'),
      $content: jQuery('#content')
    }

    Object.assign(this, internals);
    this.set_bindings();
  }

  set_bindings() {
    this.$submitButtons.prop('disabled', false);//make sure submit buttons are enabled when the dom is loaded!

    this.$setGeocodeBtn.bind('click.setGeoCodeBind', function () {
      const _selectedItemData = jQuery('input[name=fix_geocode]:checked').data();
      if (_selectedItemData) {
        jQuery('#observation_lat').val(_selectedItemData.geocode.latitude);
        jQuery('#observation_long').val(_selectedItemData.geocode.longitude);
        jQuery('#observation_alt').val(_selectedItemData.geocode.altitude);
        this.$geocodeMessages.hide('slow');
      }
    });

    this.$ignoreGeocodeBtn.bind('click', function () {
      this.$geocodeMessages.hide('slow');
    });


    jQuery('body').on('click', '[data-role="show_on_map"]', function () {
      this.showGeocodeonMap((jQuery(this).data().geocode));
    });


    $fixDateSubmit.bind('click.fixDateBind', function () {
      var _selectedItemData = jQuery('input[name=fix_date]:checked').data();
      if (_selectedItemData && _selectedItemData.date) {
        this.dateUpdater.fixDates(_selectedItemData.date, _selectedItemData.target);
      }
    });

    this.$ignoreDateSubmit.bind('click.ignoreDateBind', function () {
      this.$imgMessages.hide('slow');
    });

    this.$obsYear.change(function () { this.dateUpdater.updateObservationDateRadio() });
    this.$obsMonth.change(function () { this.dateUpdater.updateObservationDateRadio() });
    this.$obsDay.change(function () { this.dateUpdater.updateObservationDateRadio() });



    //Drag and Drop bindings on the window

    this.$content.bind('dragover dragenter', function (e) {
      if (e.preventDefault) { e.preventDefault(); }
      jQuery('#right_side').addClass('dashed-border');
      return false;
    });

    this.$content.bind('dragend dragleave dragexit', function (e) {
      jQuery('#right_side').removeClass('dashed-border');
    });

    this.$content.bind('drop', function (e) {
      if (e.preventDefault) { e.preventDefault(); }  // stops the browser from leaving page
      jQuery('#right_side').removeClass('dashed-border');
      const dataTransfer = e.originalEvent.dataTransfer;
      if (dataTransfer.files.length > 0)
        this.fileStore.addFiles(dataTransfer.files);
      // There are issues to work out concerning dragging and dropping
      // images from other websites into the observation form.
      // else
      //   fileStore.addUrl(dataTransfer.getData('Text'));
    });

    // Detect when files are added from browser
    this.$selectFilesButton.change(function () {
      var files = $(this)[0].files; //Get the files from the browser
      this.fileStore.addFiles(files);
    });

    // IMPORTANT:  This allows the user to update the thumbnail on the edit
    // observation view.
    jQuery('input[type="radio"][name="observation[thumb_image_id]"]').change(function () {
      jQuery('#observation_thumb_image_id').val($(this).val());
    });

    // Logic for setting the default thumbnail
    jQuery('body').on('click', '[data-role="set_as_default_thumbnail"]', function (event) {
      const $this = jQuery(this); //the link clicked to make default image

      event.preventDefault();

      //reset selections

      //remove hidden from the links
      jQuery('[data-role="set_as_default_thumbnail"]').removeClass('hidden');
      //add hidden to the default thumbnail text
      jQuery('.is_default_thumbnail').addClass('hidden');
      //reset teh chcked default thumbnail
      jQuery('input[type="radio"][name="observation[thumb_image_id]"]').prop('checked', false);


      //set selections

      //add hidden to the link clicked
      $this.addClass('hidden');
      //show that the image is default
      $this.siblings('.is_default_thumbnail').removeClass('hidden');
      //adjust hidden radio button to select default thumbnail
      $this.siblings('input[type="radio"][name="observation[thumb_image_id]"]').prop('checked', true);


    });

    // Detect when a user submits observation; includes upload logic

    this.$form.submit(function (event) {
      //  event.preventDefault();
      if (this.blockFormSubmission) {
        this.fileStore.uploadAll();
        return false;
      }
      return true;
    });
  }

  /*********************/
  /*    Helpers    */
  /*********************/

  generateUUID() {
    return 'xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
      var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }

  /**Geocode Helpers**/

  makeGeocodeRadioBtn(latLngObjct) {
    var html = "<div class='radio'><label><input type='radio' data-geocode='{{geocode}}' name='fix_geocode'/>{{geoCodeStr}}</label> " +
      "<a href='#geocode_map' data-role='show_on_map' class='ml-3' data-geocode='{{geocodeForMap}}'>" + localized_text.show_on_map + "</a></div>";
    html = html.replace('{{geocode}}', JSON.stringify(latLngObjct));
    html = html.replace('{{geocodeForMap}}', JSON.stringify(latLngObjct));
    html = html.replace('{{geoCodeStr}}', latLngObjct.latitude.toFixed(5) + ", " + latLngObjct.longitude.toFixed(5));
    return html;
  }

  getLatitudeLongitudeFromEXIF(exifObject) {

    var lat = exifObject.GPSLatitude[0] + (exifObject.GPSLatitude[1] / 60.0) + (exifObject.GPSLatitude[2] / 3600.0);
    var long = exifObject.GPSLongitude[0] + (exifObject.GPSLongitude[1] / 60.0) + (exifObject.GPSLongitude[2] / 3600.0);
    var alt = exifObject.GPSAltitude ? (exifObject.GPSAltitude.numerator / exifObject.GPSAltitude.denominator).toFixed(0) + " m" : ""
    //make sure you don't end up on the wrong side of the world
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
    var obsLatLongFormat = { lat: latLngObj.latitude, lng: latLngObj.longitude }
    // jQuery('#geocode_map').width('100%'); // css class w-100 on the div
    jQuery('#geocode_map').height('250');
    var map = new google.maps.Map(document.getElementById('geocode_map'), {
      center: obsLatLongFormat,
      zoom: 12
    });

    var marker = new google.maps.Marker({
      map: map,
      position: obsLatLongFormat
    });
  }
}


/*********************/
/*   Bindings    */
/*********************/


return {
  init: init
}

