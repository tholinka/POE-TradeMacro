If (!FileExist(A_ScriptDir "\_TradeMacroMain.ahk")) {
	RunWait, Run_Only_This.ahk
	While (!FileExist(A_ScriptDir "\_TradeMacroMain.ahk")) {
		Sleep, 500
	}
}

SplitPath, A_AhkPath,, AhkDir
RunWait %comspec% /c ""%AhkDir%"\Compiler\Ahk2Exe.exe /in "_TradeMacroMain.ahk" /out "PoE-TradeMacro_(Fallback).exe" /icon "resources\images\poe-trade-bl.ico""
ExitApp