#Include, CalcChecksum.ahk
#Include, %A_ScriptDir%\lib\DebugPrintArray.ahk

PoEScripts_HanldeUserSettings(ProjectName, External, FilesToCopy, Dir = "") {
	If (!StrLen(Dir)) {
		Dir := A_MyDocuments . "\" . ProjectName
	}
	PoEScripts_CreateDirIfNotExist(Dir)

	; External is set if the user settings folder is handled by another script
	If (External) {
		; copy files after checking if it's neccessary (files do not exist, files were changed in latest update)
		; copy .ini files and AdditionalMacros.txt to A_MyDocuments/ProjectName
		PoEScripts_CopyFiles(FilesToCopy, Dir)
	}
	Else {
		; copy files after checking if it's neccessary (files do not exist, files were changed in latest update)
		; this handles the external scripts files
		PoEScripts_CopyFiles(FilesToCopy, Dir)
	}
}

PoEScripts_CopyFiles(Files, Dir) {
	tempObj 		:= PoEScripts_ParseFileHashes(Dir)
	hashes 		:= tempObj.dynamic
	hashes_locked 	:= tempObj.static

	fileNames := []
	overwrittenFiles := []
	FileRemoveDir, %Dir%\temp, 1
	FileCreateDir, %Dir%\temp
	
	For key, file in Files {
		If (FileExist(file)) {
			; remove "default_" prefix in file-names and copy them to temp folder
			SplitPath, file, f_name, f_dir, f_ext, f_name_no_ext, f_drive
			file_orig := file
			file_name := RegExReplace(f_name_no_ext, "i)default_", "") . "." . f_ext
			FileCopy, %file%, %Dir%\temp\%file_name%
			file := f_dir . "\" . file_name			
			fileNames.push(file_name)
			
			; hash the file from the new script version
			sourceHash := HashFile(Dir . "\temp\" . file_name, "SHA")
			hashes[file_name] := sourceHash
			
			; if the file from the new release was changed since the last release or does not exist, copy it over
			If (PoEScripts_CopyNeeded(file, Dir, sourceHash, hashes_locked)) {
				; remember which files we will overwrite and create backups
				If (FileExist(Dir "\" file_name)) {
					overwrittenFiles.push(file_name)
					PoEScripts_CreateDirIfNotExist(Dir "\backup")
					FileMove, %Dir%\%file_name%, %Dir%\backup\%file_name%, 1
				}				
				FileCopy, %Dir%\temp\%file_name%, %Dir%\%file_name%, 1
			}			
			FileDelete, %Dir%\temp\%file_name%			
		}
	}
	
	; recreate hashes file and fill it with array/object contents
	FileDelete, %Dir%\data\FileHashes.txt
	For key, hash in hashes {
		; make sure to write only hashes for files that we wanted to copy over,  removing files not included in the new release
		For k, name in fileNames {
			If (key == name) {
				PoEScripts_CreateDirIfNotExist(Dir "\data")
				FileAppend, %key% = %hash%`n, %Dir%\data\FileHashes.txt
			}			
		}
	}
	
	; give the user some notice on what files were overwritten and backed up
	If (overwrittenFiles.Length()) {
		fileList := ""
		Loop, % overwrittenFiles.Length() {
			fileList .= "- " . overwrittenFiles[A_Index] . "`n"
		}
		MsgBox % "Following user files were changed in last update and were overwritten (old files were backed up): `n`n" . fileList
	}
	
	FileRemoveDir, %Dir%\temp, 1
}

PoEScripts_CopyNeeded(file, targetDir, sourceHash, hashes_locked) {
	SplitPath, file, f_name, f_dir, f_ext, f_name_no_ext, f_drive

	If (FileExist(targetDir . "\" . f_name)) {
		; file exists already in target folder
		If (PoEScripts_CompareFileHashes(f_name, sourceHash, hashes_locked)) {
			; file hashes are different = file was changed since last release
			Return 1
		}
		Else {
			Return 0	
		}		
	}
	Else {
		; file doesn't exist in target folder
		return 1
	}
}

PoEScripts_ParseFileHashes(Dir) {
	hashes := {}
	hashes.dynamic := {}
	hashes.static  := {}
	FileRead, fileData, %Dir%\data\FileHashes.txt

	Loop, Parse, fileData, `n, `r
	{
		RegExMatch(A_LoopField, "(.*)\s=\s(.*)", match)
		hashes.dynamic[Trim(match1)] := Trim(match2)
		hashes.static[Trim(match1)]  := Trim(match2) 
	}	

	Return hashes
}

PoEScripts_CreateDirIfNotExist(directory) {	
	If (!InStr(FileExist(directory), "D")) {
		FileCreateDir, %directory%
	}
}

PoEScripts_CompareFileHashes(name, sourceHash, hashes_locked) {
	If (hashes_locked[name] != sourceHash) {
		Return 1
	}
	Return 0
}