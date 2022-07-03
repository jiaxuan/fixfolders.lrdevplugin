--[[----------------------------------------------------------------------------

ShowFixFoldersDialog.lua
Fix file folders that don't match capture timestamp.

------------------------------------------------------------------------------]]

local LrApplication = import 'LrApplication'
local LrFunctionContext = import 'LrFunctionContext'
local LrBinding = import 'LrBinding'
local LrDate = import 'LrDate'
local LrDialogs = import 'LrDialogs'
local LrLogger = import 'LrLogger'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'
local LrColor = import 'LrColor'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'

local fileLogger = LrLogger( 'fixfolders' )
fileLogger:enable( "logfile" )

local function log( message )
	fileLogger:info( message )
end

local activeCatalog = LrApplication.activeCatalog()

local function showFixFoldersDialog()

	LrFunctionContext.callWithContext( "showFixFoldersDialog", function( context )

	    local f = LrView.osFactory()
		local as = activeCatalog:getActiveSources()

		if #as ~= 1 or as[1]:type() ~= "LrFolder" then
			LrDialogs.message( "Invalid context", "Select a folder first" )
			return
		end

		local toMove = {}

		LrTasks.startAsyncTask(function()

			-- ###########################################################################
			-- Scan folders
			-- ###########################################################################

			LrFunctionContext.callWithContext( "showScanningDialog", function( context )

				-- Scan folders for capture time/folder mismatch

				local progressScope = LrDialogs.showModalProgressDialog( { title="Scanning folder ".. as[1]:getName(), functionContext=context } )

				local subFolders = {as[1]}

				if not string.find(as[1]:getName(), "-") then
					subFolders = as[1]:getChildren()
				end

				local total = 0
				local totalAmount = #subFolders * 10000
				local amountDone = 0

				for i=1,#subFolders do

					local folder = subFolders[i]
					photos = folder:getPhotos(False)

					for j=1,#photos do
						total = total + 1
						local time
						local photo = photos[j]

						for index, value in pairs({"dateTimeDigitized", "dateTimeOriginal", "dateTime", "captureTime"}) do
							time = photo:getRawMetadata(value)
							if time then
								break
							end
						end

						if time then
							local year, month, day = LrDate.timestampToComponents( time )
							local targetFolder = string.format("%4d-%02d-%02d", year, month, day)
							if year > 1900 and targetFolder ~= folder:getName() then
								local path = photo:getRawMetadata("path")
								local file = LrPathUtils.leafName(path)
								local sourceDir = LrPathUtils.parent(path)

								local targetPath = LrPathUtils.child(LrPathUtils.parent(sourceDir), targetFolder)
								-- check year
								if tonumber(LrPathUtils.leafName(sourceDir)) ~= year then
									targetPath = LrPathUtils.child(LrPathUtils.child(LrPathUtils.parent(LrPathUtils.parent(sourceDir)), tostring(year)), targetFolder)
								end

								toMove[#toMove+1] = {media=photo, source=path, file=file, target=LrPathUtils.child(targetPath, file)}
							end
						else
							log("[WARN] failed to process " .. photo:getRawMetadata("path"))
							-- local meta = photo:getRawMetadata()
							-- for index, value in pairs(meta) do
							-- 	log(index .. ": ...")
							-- end
						end

						progressScope:setPortionComplete( amountDone + j * 10000 / #photos, totalAmount )
					end

					amountDone = i * 10000
					progressScope:setPortionComplete( amountDone, totalAmount )
					progressScope:setCaption( total .. " files scanned, " .. #toMove .. " files to update" )
				end

				progressScope:done()
			end)

			-- ###########################################################################
			-- Show scan result and fix the issues
			-- ###########################################################################

			LrFunctionContext.callWithContext( "showFileListDialog", function( context )

				-- Hack: ensure the progress dialog disappears first. Is there a better way?
				LrTasks.yield()
				LrTasks.sleep(0.5)

				if #toMove == 0 then
					LrDialogs.message( "Nothing to update", "Everything looks good" )
					return
				end

				local pageSize = 20
				local lineWidth = 150
				local currentPage = 1
				local totalPages = math.ceil(#toMove / pageSize)

				local padString = function(s)
					if string.len(s) < lineWidth then
						s = s .. string.rep(" ", lineWidth - string.len(s))
					else
						lineWidth = string.len(s)
					end
					return s
				end

				local printPage = function(entries, currentPage)
					local start = (currentPage - 1) * pageSize + 1
					local last = start + pageSize - 1
					if last > #entries then
						last = #entries
					end

					local lines = ""
					for i=start,last do
						local line = padString(entries[i]["source"] .. " -> " .. entries[i]["target"])
						if i == start then
							lines = line
						else
							lines = lines .. "\n" .. line
						end
					end
					return lines
				end

				local staticTextListTitle = f:static_text {
					height_in_lines = 1,
					title = "Page " .. currentPage .. "/" .. totalPages .. "     ",
				}

				local staticTextFileList = f:static_text {
					height_in_lines = 1,
					title = printPage(toMove, 1),
				}

				local updateCurrentPage = function()
					staticTextListTitle.title = "Page " .. currentPage .. "/" .. totalPages
					staticTextFileList.title = printPage(toMove, currentPage)
				end

				local prevPage = function()
					if currentPage > 1 then
						currentPage = currentPage - 1
						updateCurrentPage()
					end
				end

				local nextPage = function()
					if currentPage < totalPages then
						currentPage = currentPage + 1
						updateCurrentPage()
					end
				end

				local result = LrDialogs.presentModalDialog {
					title = #toMove .. " files to be updated",
					contents = f:column {
						spacing = f:dialog_spacing(),

						f:row{
							fill_horizontal  = 1,
							staticTextListTitle,
							f:push_button {
								title = "<",
								action = prevPage,
							},
							f:push_button {
								title = ">",
								action = nextPage,
							},
						},

						f:row{
							fill_horizontal  = 1,
							staticTextFileList,
						},
					},
					actionVerb = "Apply",
				}

				if result ~= "ok" then
					return
				end

				-- Copy files to their new folders
				-- Remove the original files from FS
				-- Add remove files to a special collection

				LrTasks.startAsyncTask(function()

					local result = activeCatalog:withWriteAccessDo("Reimport photos", function(context)

						local collectionName = os.date("ToDelete-%H%M%S-%Y%m%d")
						local collection = activeCatalog:createCollection( collectionName )
						local toAdd = {}

						if collection and type(collection) == "table" then

							local progressScope = LrDialogs.showModalProgressDialog( { title="Fixing file folders...", functionContext=context } )

							for i=1,#toMove do

								log("OK collection " .. collectionName .. " created")

								local media = toMove[i]["media"]
								local source = toMove[i]["source"]
								local target = toMove[i]["target"]

								local targetDir = LrPathUtils.parent(target)
								if not LrFileUtils.exists(targetDir) then
									LrFileUtils.createAllDirectories(targetDir)
								end

								if not LrFileUtils.copy(source, target) then
									log("[ERROR] failed to copy " .. source .. " to " .. target)
								else
									-- log("OK " .. source .. " copied to " .. target)
									local p = media.catalog:addPhoto(target)
									if p:type() == 'LrPhoto' then
										toAdd[#toAdd+1] = media

										if not LrFileUtils.moveToTrash(source) then
											log("[ERROR] failed to remove " .. source)
										end
									else
										log("[ERROR] failed to import media " .. target)
									end
								end

								progressScope:setPortionComplete( i, #toMove )
								progressScope:setCaption( i .. " files to update" )
							end

							collection:addPhotos(toAdd)
							progressScope:done()

						else
							LrDialogs.message("Operation Failed", "Failed to create collection " .. collectionName, "warning")
						end

					end, {timeout=10})
				end)
			end)
		end)
	end)
end

showFixFoldersDialog()
