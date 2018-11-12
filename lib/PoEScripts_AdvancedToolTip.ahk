#SingleInstance, force
#Include, %A_ScriptDir%\Class_AdvancedToolTipGui.ahk
#Include, %A_ScriptDir%\JSON.ahk
#Include, %A_ScriptDir%\DebugPrintArray.ahk

#NoTrayIcon

FileRead, ttDump, %A_ScriptDir%\..\temp\advtooltip.json
ttData := JSON.Load(ttDump)

; ==================================================================================================================================
; Function	__New
;			Creates a new ToolTip instance.
; Parameters:
; 		GuiName			- Name of the ToolTip gui.
;		borderColor		- ToolTip border color.
;		backgroundColor	- ToolTip background color.
;		borderWidth		- ToolTip border width.
;		opacity			- ToolTip window opacity (0 - 255).
;		defTTFont			- Default ToolTip font (family).
;		defTTFontSize		- Default ToolTip font size.
;		timeoutInterval	- ToolTip timeout/timer interval.
;		mouseMoveThreshold	- Distance in pixel that have to be moved to remove the ToolTip.
;		useToolTipTimeout	- Whether to timeout the ToolTip after a certain time.
;		toolTipTimeoutSec	- ToolTip timeout time in seconds.
;		xPos				- Default ToolTip x coordinate (used in case of using fixed coordinates).
;		yPos				- Default ToolTip y coordinate (used in case of using fixed coordinates).
;		usedFixedCoords	- Whether to draw the ToolTip at fixed coordinates or use the current mouse position.
;		appAHKGroup		- Name of the ahk_group that contains the target application, optional.
;		appAHKID			- ahk_id of the target application, optional.
;		exitAppOnTTClose	- if "true" a tooltip close will exit the app.
; ==================================================================================================================================
global AdvTT := new AdvancedToolTipGui(ttData.GuiName, ttData.borderColor, ttData.backgroundColor, ttData.borderWidth, ttData.opacity, ttData.defTTFont, ttData.defTTFontSize, ttData.timeoutInterval, ttData.mouseMoveThreshold, ttData.useToolTipTimeout, ttData.toolTipTimeoutSec, ttData.xPos, ttData.yPos, ttData.usedFixedCoords, ttData.appAHKGroup, ttData.appAHKID, true)
AdvTT.CreateGui()

For k, v in ttData.tables {
	;AddTable(fontSize = -1, font = "", color = "Default", grid = "fullGrid", guiMargin = 5, topMargin = 0, tableXPos = "", tableYPos = "", assocVar = "")
	AdvTT.AddTable(v.FontSize, v.font, v.fColor, v.gridType, v.guiMargin, v.topMargin, v.tableXPos, v.tableYPos, v.assocVar)
	
	For j, r in v.rows {
		For i, c in r {
			;AddCell(tableIndex, rowIndex, cellIndex, value, alignment = "left", fontOptions = "", bgColor = "Trans", isSpacingCell = false, fColor = "", font = "")	
			AdvTT.AddCell(k, j, i, c.value, c.alignment, c.fontOptions, c.bgColor, c.isSpacingCell, c.fColor, c.font)
			
			For l, sc in c.subCells {
				;AddSubCell(tableIndex, rI, cI, sCI, value, alignment = "left", fontOptions = "", bgColor = "Trans", isSpacingCell = false, fColor = "", font = "", noSpacing = false)
				AdvTT.AddSubCell(k, j, i, l, sc.value, sc.alignment, sc.fontOptions, sc.bgColor, sc.isSpacingCell, sc.fColor, sc.font, sc.noSpacing)
			}
		}
	}
}

; for winmerge comparison 
dumpObj := JSON.Dump(ttData, "", 3)
file := A_ScriptDir "\..\temp\1.txt"
FileDelete, %file%
FileAppend, %dumpObj%, %file%

dumpObj := JSON.Dump(AdvTT, "", 3)
file := A_ScriptDir "\..\temp\2.txt"
FileDelete, %file% 
FileAppend, %dumpObj%, %file%


AdvTT.DrawTables()
AdvTT.ShowToolTip()

Return
