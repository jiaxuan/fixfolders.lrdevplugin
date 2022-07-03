A simple Lightroom Classic plugin to reorganize media based on their capture timestamp. To install:

- Clone this repo
- In Lightroom, navigate to *File > Plug-in Manager... > Add* and select the check-out folder

A proper installation should add a menu entry *Reorganize media based on capture time* to *Library > Plug-in Extras*.

To use it, select a *folder* in the Library module and click the menu entry, the plugin:

- scans all the files in the folder
- shows the list of detected files

If you click *Apply*, the following updates are applied:

- the files are copied to new folders that match their capture time and imported into Lightroom
- the old files are removed from the file system. They are also added to a special collection named *ToDelete-HHMMSS-YYYYmmdd*

Due to the limitation of the Lightroom Classic SDK this plugin is based on, it is not possible to remove the old files from the Lightroom catalog programmatically. Although the media files in the old folders have been removed from the file system, they still appear under those folders in Lightroom. To make them disappear from Lightroom's catalog,

- click the special collection created above
- select all the media in the collection
- select the menu item *Photo > Remove Photo from Catalog*
- remove the collection

Tested on Windows only. Feel free to fork and extend it.
