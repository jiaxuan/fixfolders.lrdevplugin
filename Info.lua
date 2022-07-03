--[[----------------------------------------------------------------------------

Info.lua
Adds a Library menu item.

------------------------------------------------------------------------------]]

return {
	LrSdkVersion = 3.0,
	LrSdkMinimumVersion = 1.3, -- minimum SDK version required by this plug-in
	LrToolkitIdentifier = 'com.adobe.lightroom.sdk.helloworld',
	LrPluginName = LOC "$$$/FixFolders/PluginName=Fix File Folders",

	LrLibraryMenuItems = {
	    {
		    title = LOC "$$$/FixFolders/CustomDialog=Reorganize media based on capture time",
		    file = "ShowFixFoldersDialog.lua",
		},
	},
	VERSION = { major=11, minor=4, revision=0, build="202207031805", },
}
