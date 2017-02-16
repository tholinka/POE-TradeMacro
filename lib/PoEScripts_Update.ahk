#Include, %A_ScriptDir%\lib\JSON.ahk
#Include, %A_ScriptDir%\lib\zip.ahk

PoEScripts_Update(user, repo, ReleaseVersion, ShowUpdateNotification, userDirectory, isDevVersion, SplashScreenTitle = "") {
	status := GetLatestRelease(user, repo, ReleaseVersion, ShowUpdateNotification, userDirectory, isDevVersion, SplashScreenTitle)
	Return status
}

GetLatestRelease(user, repo, ReleaseVersion, ShowUpdateNotification, userDirectory, isDevVersion, SplashScreenTitle = "") {
	If (ShowUpdateNotification = 0) {
		return
	}
	HttpObj := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	url := "https://api.github.com/repos/" . user . "/" . repo . "/releases"
	downloadUrl := "https://github.com/" . user . "/" . repo . "/releases"
	
	Try  {
		Encoding := "utf-8"
		HttpObj.Open("GET",url)
		HttpObj.SetRequestHeader("Content-type","application/html")
		HttpObj.Send("")
		HttpObj.WaitForResponse()

		Try {				
			If Encoding {
				oADO          := ComObjCreate("adodb.stream")
				oADO.Type     := 1
				oADO.Mode     := 3
				oADO.Open()
				oADO.Write(HttpObj.ResponseBody)
				oADO.Position := 0
				oADO.Type     := 2
				oADO.Charset  := Encoding
				html := oADO.ReadText()
				oADO.Close()
			}
		} Catch e {			
			html := HttpObj.ResponseText
			If (TradeOpts.Debug) {
				MsgBox, 16,, % "Exception thrown!`n`nwhat: " e.what "`nfile: " e.file	"`nline: " e.line "`nmessage: " e.message "`nextra: " e.extra
			}
		}
		
		parsedJSON := JSON.Load(html)
		LatestRelease := {}
		LastXReleases := []
		updateNotes := ""
		i := 0
		showReleases  := 5
		For key, val in parsedJSON {
			i++
			If (i <= showReleases) {
				tempObj := {}
				tempObj.notes 		:= ParseDescription(val.body)
				tempObj.tag 		:= val.tag_name
				tempObj.published 	:= ParsePublishDate(val.published_at)
				tempObj.textBlock 	:= CreateTextBlock(tempObj.notes, tempObj.published, tempObj.tag)
				updateNotes 		.= tempObj.textBlock
				LastXReleases.push(tempObj)
			}
		}
		For key, val in parsedJSON {			
			If (not val.draft) {
				LatestRelease := val				
				Break
			}
		}

		; get download link to zip files (normal release zip and asset zip file)
		UrlParts := StrSplit(LatestRelease.zipball_url, "/")
		downloadFile 		:= UrlParts[UrlParts.MaxIndex()] . ".zip"
		downloadURL_zip 	:= "https://github.com/" . user . "/" . repo . "/archive/" . downloadFile
		downloadURL_asset 	:= ""
		If (LatestRelease.assets.Length()) {
			For key, val in LatestRelease.assets {
				If (val.content_type = "application/zip") {
					downloadURL_asset := val.browser_download_url
				}
			}
		}
		
		global updateWindow_Project 		:= repo
		global updateWindow_DefaultFolder	:= A_ScriptDir
		global updateWindow_isDevVersion	:= isDevVersion
		global updateWindow_downloadURL	:= StrLen(downloadURL_asset) ? downloadURL_asset : downloadURL_zip
		
		isPrerelease:= LatestRelease.prerelease
		releaseTag  := LatestRelease.tag_name
		releaseURL  := downloadUrl . "/tag/" . releaseTag
		publisedAt  := LatestRelease.published_at
		description := LatestRelease.body
		
		RegExReplace(releaseTag, "^v", releaseTag)
		versions		:= ParseVersionStringsToObject(releaseTag, ReleaseVersion)
		
		newRelease := CompareVersions(versions.latest, versions.current)
		If (newRelease) {
			If(SplashScreenTitle) {
				WinSet, AlwaysOnTop, Off, %SplashScreenTitle%
			}
			Gui, UpdateNotification:Font,, Consolas
			
			boxHeight := isPrerelease ? 80 : 60
			Gui, UpdateNotification:Add, GroupBox, w580 h%boxHeight% cGreen, Update available!			
			If (isPrerelease) {
				Gui, UpdateNotification:Add, Text, x20 yp+20, Warning: This is a pre-release.
				Gui, UpdateNotification:Add, Text, x20 y+10, Installed version:
			} Else {
				Gui, UpdateNotification:Add, Text, x20 yp+20, Installed version:
			}
			
			currentLabel := versions.current.label
			latestLabel  := versions.latest.label
			
			Gui, UpdateNotification:Add, Text, x150 yp+0,  %currentLabel%	
			
			Gui, UpdateNotification:Add, Text, x20 y+0, Latest version:
			
			Gui, UpdateNotification:Add, Text, x150 yp+0,  %latestLabel%
			Gui, UpdateNotification:Add, Link, x+20 yp+0 cBlue, <a href="%releaseURL%">Download it here</a>
			Gui, UpdateNotification:Add, Button, x+20 yp-5 gUpdateScript, Update
			
			Gui, UpdateNotification:Add, Text, x10 cGreen, Update notes:
			Gui, UpdateNotification:Add, Edit, r20 ReadOnly w580 BackgroundTrans, %updateNotes%
			
			Gui, UpdateNotification:Add, Button, gCloseUpdateWindow, Close
			Gui, UpdateNotification:Show, w600 xCenter yCenter, Update 
			ControlFocus, Update, Update
			WinWaitClose, Update
		}
		Else {
			s := "no update"
			Return s
		}
	} Catch e {
		MsgBox,,, % "Update-Check failed, Exception thrown!`n`nwhat: " e.what "`nfile: " e.file	"`nline: " e.line "`nmessage: " e.message "`nextra: " e.extra
	}
	
	Return
}

ParseDescription(description) {
	description := RegExReplace(description, "iU)\\""", """")
	StringReplace, description, description, \r\n, §, All 
	StringReplace, description, description, \n, §, All

	Return description
}

ParsePublishDate(date) {	
	TimeStr := RegExReplace(date, "i)-|T|:|Z")	
	FormatTime, TimeStr, %TimeStr%, ShortDate
	Return TimeStr
}

CreateTextBlock(description, date, tag) {
	block := "-----------------------------------------------------------------------------------------" . "`n"
	block .= "[" . date . "]  Version: " . tag . "`n"
	block .= "-----------------------------------------------------------------------------------------" . "`n"
	block .= description . "`n`n"
	
	Return block
}

CompareVersions(latest, current) {
	; new release available if latest is higher than current
	versionHigher 		:= false
	subVersionHigher 	:= false
	
	If (not latest.major and not current.major) {
		Return false
	}
	Else {
		equal := latest.major . latest.minor . latest.patch . "" == current.major . current.minor . current.patch . ""

		If (RemoveLeadingZeros(latest.major) > RemoveLeadingZeros(current.major)) {
			versionHigher := true
		}
		Else If (RemoveLeadingZeros(latest.minor) > RemoveLeadingZeros(current.minor)) {
			versionHigher := true
		}
		Else If (RemoveLeadingZeros(latest.patch) > RemoveLeadingZeros(current.patch)) {
			versionHigher := true
		}
		
		If (latest.subVersion.priority or current.subVersion.priority) {
			If (current.subVersion.priority and latest.fullRelease) {
				subVersionHigher := false
			}
			Else If (latest.subVersion.priority > current.subVersion.priority) {
				subVersionHigher := true
			}
			Else If (RemoveLeadingZeros(latest.subVersion.patch) > RemoveLeadingZeros(current.subVersion.patch)) {
				subVersionHigher := true
			}
		}

		
		If (equal and latest.fullRelease and not current.fullRelease) {
			Return true
		}
		Else If (equal and not subVersionHigher) {
			Return false
		}
		Else If (versionHigher) {
			Return true
		}
		Else If (subVersionHigher) {
			Return true
		}
		Else {
			Return false
		}
	}
}

RemoveLeadingZeros(in) {
	Return LTrim(in, "0")
}

ParseVersionStringsToObject(latest, current) {
     ; requires valid semantic versioning
	; x.x.x
	; x.x.x-alpha.x
	; also possible: beta, rc
	; priority: normal release (no sub version) > rc > beta > alpha
	RegExMatch(latest, "(\d+).(\d+).(\d+)(.*)", latestVersion)
	RegExMatch(current, "(\d+).(\d+).(\d+)(.*)", currentVersion)

	If (StrLen(latest) < 1) {
		MsgBox, 16,, % "Exception thrown! Parsing release information from Github failed."
	}
	
	versions := {}
	versions.latest  := {}
	versions.current := {}

	RegExMatch(latestVersion4,  "i)(rc|beta|alpha)(.?(\d+)(.*)?)?", match_latest)
	RegExMatch(currentVersion4, "i)(rc|beta|alpha)(.?(\d+)(.*)?)?", match_current)

	temp := ["latest", "current"]
	For key, val in temp {
		versions[val].major := %val%Version1
		versions[val].minor := %val%Version2
		versions[val].patch := %val%Version3
		versions[val].label := %val%Version

		If (match_%val%) {	
			versions[val].subVersion := {}
			versions[val].subVersion.identifier:= match_%val%1
			versions[val].subVersion.priority	:= GetVersionIdentifierPriority(versions[val].subVersion.identifier)
			versions[val].subVersion.patch	:= match_%val%3	
		}
		
		versions[val].fullRelease := StrLen(match_%val%) < 1 ? true : false
	}
	
	Return versions
}

GetVersionIdentifierPriority(identifier) {
	If (identifier = "rc") {
		Return 3
	} Else If (identifier = "beta") {
		Return 2
	} Else If (identifier = "alpha") {
		Return 1
	} Else {
		Return 0
	}
}

UpdateScript(url, project, defaultDir, isDevVersion) {	
	prompt := "Please select the folder you want to install/extract " project " to.`n"
	prompt .= "Selecting an existing folder will ask for confirmation and will back up that folder, for example 'MyFolder_backup'."
	
	defaultFolder := RegExReplace(defaultDir, "i)[^\\]+$", "")
	; append '_devUpdate' to the folder if it's a development version (.git folder exists)
	defaultFolder := StrLen(isDevVersion) > 0 ? defaultFolder . project . "_devUpdate" : defaultFolder . project
	; check for equality but ignore case sensitivity (prefer current script dir)
	defaultFolder := (defaultFolder != defaultDir) ? defaultFolder : defaultDir
	
	; create dev folder if it doesn't exist, remove it later if not used
	createdFolder := false
	If (!InStr(FileExist(defaultFolder), "D")) {
		createdFolder := true
		FileCreateDir, %defaultFolder%
	}
	
	FileSelectFolder, InstallPath, *%defaultFolder%, 1, %prompt%
	If (ErrorLevel) {
		; dialog canceled, do nothing
	} 
	Else If (InstallPath = ) {
		MsgBox, You didn't select a folder.
	}	    
	Else {		
		; remove created dev folder if unused
		If (createdFolder and defaultFolder != InstallPath) {
			FileRemoveDir, %defaultFolder%, 1
		}
		; check if install folder is empty 
		If (not IsEmpty(InstallPath)) {
			MsgBox, 4,, Folder (%InstallPath%) is not empty, overwrite it after making a backup?
			IfMsgBox Yes 
			{				
				Gui, Cancel
				; remove backup folder if it already exists
				If (InStr(FileExist(InstallPath "_backup"), "D")) {
					FileRemoveDir, %InstallPath%_backup, 1
				}
				FileMoveDir, %InstallPath%, %InstallPath%_backup, R  ; Simple rename.
			}
			IfMsgBox No 
			{
				Return
			}
		}
		Else {		
			Gui, Cancel
		}

		savePath := "" ; ByRef
		If (DownloadRelease(url, project, savePath)) {
			folderName := ExtractRelease(savePath, project)
			If (StrLen(folderName)) {
				; successfully downloaded and extracted release.zip to %A_Temp%\%Project%\ext
				; copy script to %A_Temp%\%Project%
				SplitPath, savePath, , saveDir
				externalScript := saveDir . "\PoEScripts_FinishUpdate.ahk"
				FileCopy, %A_ScriptDir%\lib\PoEScripts_FinishUpdate.ahk, %externalScript%, 1
				
				; try to run the script and exit the app
				; this needs to be done so that we can overwrite the current scripts directory
				If (FileExist(externalScript)) {
					Run "%A_AhkPath%" "%externalScript%" "%A_ScriptDir%" "%folderName%" "%InstallPath%" "%project%"
					If (ErrorLevel) {
						MsgBox Update failed, couldn't launch 'FinishUpdate' script. File not found.
					}
				}
				Else {
					MsgBox Update failed, couldn't launch 'FinishUpdate' script.
				}				
				ExitApp
			}
		}		
	}
}

DownloadRelease(URL, project, ByRef savePath) {
	static nothing := ComObjError(0)
	static oHTTP   := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	static oADO    := ComObjCreate("adodb.stream")
	
	SplashTextOn, 300, 20, %project% update, Downloading .zip archive...
	oHTTP.Open("GET",url)
	oHTTP.SetRequestHeader("Content-type","application/octet-stream")
	; we need the useragent with the repository name to download files
	oHTTP.SetRequestHeader("User-Agent", project)
	oHTTP.Send("")
	oHTTP.WaitForResponse()

	savePath := A_Temp . "\" . project . "\" . "release.zip"
	If (!InStr(FileExist(A_Temp "\" project), "D")) {
		FileCreateDir, %A_Temp%\%project%
	}
	
	oADO.Type := 1 ; adTypeBinary = 1
	oADO.Open()
	oADO.Write( oHTTP.ResponseBody )
	oADO.SaveToFile( savePath, 2 )
	oADO.Close()
	SplashTextOff
	
	If (oHTTP.Status != 200) {
		MsgBox, 16,, % "Error downloading file. HTTP status: " oHTTP.Status " " oHTTP.StatusText 
		Return False
	}
	
	; not sure if this is neccessary
	FileGetSize, sizeOnDisk, %SavePath%
	size := oHTTP.GetResponseHeader("Content-Length")	
	If (size == sizeOnDisk) {
		MsgBox, 5,, % "Error: size of downloaded file is incorrect.`n`nUpdate has been cancelled."
		IfMsgBox, Retry
		{
			DownloadRelease(URL, project, savePath)			
		}
		IfMsgBox, Cancel 
		{
			Return False	
		}
	}	
	; MsgBox % "HTTP/1.1 " oHTTP.Status " " oHTTP.StatusText "`n" oHTTP.GetAllResponseHeaders()
	
	Return True
}

ExtractRelease(file, project) {
	SplitPath, file, f_name, f_dir, f_ext, f_name_no_ext, f_drive
	sUnz := f_dir "\ext"  ; Directory to unzip files	
	
	; empty extraction sub-directory
	Try {
		FileRemoveDir, %sUnz%, 1	
	} Catch e {
		
	}
	FileCreateDir, %sUnz%
	
	; extract release.zip
	SplashTextOn, 300, 20, %project% update, Extracting downloaded .zip archive...
	Extract2Folder(file,sUnz)
	SplashTextOff
	
	; find folder name of extracted archive (to be sure we know the right one)
	Loop, %sUnz%\*, 1, 0
	{
		folderName = %A_LoopFileLongPath%
	}
	
	Return folderName
}

IsEmpty(Dir){
	Loop %Dir%\*.*, 0, 1
		return 0
	return 1
}

CloseUpdateWindow:
	Gui, Cancel
Return

UpdateScript:
	UpdateScript(updateWindow_downloadURL, updateWindow_Project, updateWindow_DefaultFolder, updateWindow_isDevVersion)	
Return