A simple Lightroom Classic plugin to reorganize media based on their capture timestamp. To install:

- Clone this repo
- In Lightroom, navigate to *File > Plug-in Manager... > Add* and select the check-out folder

A proper installation should add a menu entry *Reorganize media based on capture time* to *Library > Plug-in Extras*.

To use it, select a *folder* in the Library module and click the menu entry, the plugin:

- scans all the files in the folder
- shows the list of detected files

If you click *Apply*, the following updates are applied:

- The files are copied to new folders that match their capture time and imported into Lightroom
- The old files are removed from the file system. They are also added to a special collection named *ToDelete-HHMMSS-YYYYmmdd*

Due to the limitation of the Lightroom Classic SDK this plugin is based, it is not possible to remove the old files from the Lightroom catalog programmatically. Although the media files in the old folders have been removed, they still appear under those folders in Lightroom. To finally remove them from Lightroom,

- click the special collection created above
- select all the media in the collection
- select the menu item *Photo > Remove Photo from Catalog*

Tested on Windows only. Feel free to fork and extend it.
