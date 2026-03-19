# MyCoPortal Update

How to [incrementally update](#incremental-updates) MO's observation collection
([MUOB](https://mycoportal.org/portal/collections/misc/collprofiles.php?collid=36))
on [MyCoPortal] (MCP).

## Summary

1. [Determine the starting date](#determine-the-starting-date).
2. [Create import files](#create-import-files).
3. [Import the files to MCP](#import-the-files-to-mcp).

> [!CAUTION]
> This process updates all fields of the records which you are updating.

## Details

### Determine the starting date

* Login to [MyCoPortal] with an account which has privileges to manage the MUOB collection.
* Go to the [MUOB Collection Profile].
* Toggle "**Manager's Control Panel**" to reveal `Administration Control Panel`.

* Click "**Processing Toolbox**" in `Administration Control Panel`,

  It should display the `Specimen Processor Control Panel`

* Click the "**Image Loading**" tab.
  You should see a `Log Files` panel with an `Image Mapping File` list.

* Find the newest Image Mapping File which has a *long* list of processed images.
  It's generally the first file.
  (There might be file(s) with a dozen or fewer processed images.
  These were tests. Ignore these.)

The list will begin like this:

```txt
  Starting to process image URLs within image mapping file
  imageMappingFile_1749352588.csv (2025-06-07 20:16:51)
  #1: Processing Catalog Number: MUOB 636
```

* Open that file and scroll to the bottom.

> [!IMPORTANT]
 Note the MUOB number after the final `Processing Catalog Number`.
 This is the `Observation.id` of the most-recent Observation imported to MCP in
 the last incremental update.

### Create import files

**Do this locally** (not on the webserver) because:
It assures that the created files are based on the same Observations; and
it avoids taxing the webserver.
**Do it as webmaster**
I think that avoids the problem of hidden location lat/lng downloading as unfundged.

* Download the latest db snapshot.
* Find the `created_at` of the most-recent Observation imported to MCP in the
  last incremental update.
  (You should have noted that at the end of [Determine the starting date](#determine-the-starting-date).)
* [http://localhost:3000/observations](http://localhost:3000/observations)
* Turn on Admin Mode
* Search for Observations
  `modified` 1 day before the above `created_at` date through tomorrow,
  with `confidence:67-100`
  >Sample pattern string:
  `modified:2025-06-06-2025-07-02 confidence:67-100`

  (The extra days insure that we won't miss Observations because of time zone differences.)
  (`confidence:67-100` limits us to Observations whose identification is
  `Promising` to `I'd Call It That`.)

* Select "**Download Observations**" in the `Actions` dropdown.

#### Create data file

* Select "**MyCoPortal Data**"
* **Download**
* Wait until your browser shows the `SaveAs` popup.
  (This could take > 5 minutes on a fast computer).
* **Save**

#### Create image list file

* Select "**MyCoPortal Images**"
* **Download**
* Wait until your browser shows the SaveAs popup
  (Should be faster than the data file.)
* **Save**

### Import the files to MCP

(The initial steps are the same as for [Determine the starting date](#determine-the-starting-date).)

* Goto [MyCoPortal][]
* Login using an MCP account which has privileges to update the MUOB collection

#### Import the data

For more information: [Importing & Uploading Data,Initiating the Upload](https://docs.symbiota.org/Collection_Manager_Guide/Importing_Uploading/#initiating-the-upload)

* Go to the [MUOB Collection Profile]
* Toggle "**Manager's Control Panel**" to reveal `Administration Control Panel`.
* Click "**Import/Update Specimen Records**" in the `Administration Control Panel`,
* **Full Text File Upload**
* either:
  * Drag your MO saved data csv report to the `Choose File` button, or:
  * Click "**Choose File**", select the saved data csv file, **Open**.
* **Analyze File** (should go to the Data Upload Module)

* Select "**dbpk**" in `Source Unique Identifier / Primary Key` pulldown.
* Select "**Leave Field unmapped**" as the `Target Field` of `dbpk`.
* **Start Upload** (leave processing status as is)
* Review the `Pending Data Transfer Report`.
* If the report is error free and has the correct number of records,
  click "**Transfer Records to Central Specimen Table**".
    > [!CAUTION]
  This overwrites all **data** fields of the Records to be updated.
  (It does not update Images.)
  This step is final and is impossible to undo!
* If anything is incorrect, do not Transfer Records;
  instead, fix the CSV file and re-upload it using the steps above.
* Wait until the Transfer finishes.

#### Add the Images

For more information: [Image/Media URL Upload](https://docs.symbiota.org/Collection_Manager_Guide/Images/media_upload_url)

> [!CAUTION]
  Symbiota chokes on imagae CSV files with more than about 19,099 rows.
  If your `MyCoPortal Images` CSV report has more than 19,000 rows,
  divide it into CSV's of 19,000 or fewer rows
  and repeat the following procedure for each of those files.

* Go back to the [MUOB Collection Profile]
* Toggle "**Manager's Control Panel**" to reveal `Administration Control Panel`.
* Click "**Import/Update Specimen Records**" in the `Administration Control Panel`,
* Select "**Extended Data Import**"
* choose the MO image csv report which you saved.
* select "**Media Field Map**" from the `Import Type` dropdown.
* **Initialize Import**.
* map `imageId` to **`originalUrl`** in `Field Mapping`,
* **Import Data**
* Wait until it finishes.

[MyCoPortal]: https://www.mycoportal.org/portal
[MUOB Collection Profile]: https://www.mycoportal.org/portal/collections/misc/collprofiles.php?collid=36

---

### Notes

#### Incremental Updates

The point of selecting a starting date is to limit the upload data and images
to those MO Observations which

* changed since the last upload, or
* haven't yet been uploaded to MCP.

While it's possible to completely replace the MUOB collection,
it's desirable to limit the data and images involved.
This generally speeds the process.
