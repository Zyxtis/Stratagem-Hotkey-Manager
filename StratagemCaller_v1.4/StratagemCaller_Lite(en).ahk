#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%
#SingleInstance force
#Persistent

global Stratagems := Object()
global StratagemNames := Object()
global OrderedStratagems := []
global Bindings := Object()
global IniFile := A_ScriptDir . "\StratagemCaller.ini"
global ActivationKey := "LControl"
global InputMode := "WASD"
global ActiveProfile := ""
global DefaultProfile := "Default"
global ActiveProfileDDL
global RealKeyDelay := 25
global ActivationKeyDelay := 25
global WFSleepDelay := 230
global DISleepDelay := 25
global DISleepDelay2 := 75
global KeyMap := {}
global screen_width, screen_height, center_x, center_y
global BASE_WIDTH := 1920
global BASE_HEIGHT := 1080
CalculateScreenCenter()
global AutoPauseActive
GameTarget := "HELLDIVERS™ 2"

Menu, Tray, NoStandard 
Menu, Tray, Add, Show, ShowGui
Menu, Tray, Add, Suspend, ToggleSuspend
Menu, Tray, Add, Reload, ReloadScript
Menu, Tray, Add, Exit, GuiClose
Menu, Tray, Default, Show

AltKeys := ["LControl", "RControl", "LShift", "RShift", "LAlt", "RAlt", "LWin", "RWin", "Tab", "XButton1", "XButton2", "MButton", "WheelUp", "WheelDown"]
AltChoiceList := "[Input]"
for index, key in AltKeys
    AltChoiceList .= "|" . key

SetAltChoice(hotkeyValue, controlName) {
    global AltKeys
    found := false
    for index, key_name in AltKeys {
        if (key_name = hotkeyValue) {
            found := true
            break
        }
    }
    if found
        GuiControl, ChooseString, %controlName%, %hotkeyValue%
    else
        GuiControl, ChooseString, %controlName%, [Input]
}
LoadStratagems()
LoadConfig()
LoadBindings()

; === (Stratagem Hotkey Manager) ===
Gui, Font, % ("cC4C4C4 s12")
Gui, Add, Text, x0 y0 w425 h30 gStartMove Background2A2A2A Border cFFFFFF +Center, Stratagem Hotkey Manager Lite
Gui, Add, Button, x+5 y0 w30 h30 gHideCustomGui, —
Gui, Add, Button, x+5 y0 w30 h30 gCloseCustomGui, X
Gui, Color, 202020
Gui, Font, s9 cC4C4C4, Segoe UI
Gui, Font, % ("cC4C4C4 s11")
Gui, Add, Tab, x10 y+0 w480 h650, Main|Settings
Gui, -Caption +LastFound
Gui, Margin, 5, 5

; Main (Tab, 1)
Gui, Tab, 1

Gui, Add, Text, vCustomProf x20 y+15 w270, 📂 Profile:
Gui, Add, DropDownList, vActiveProfileDDL gSwitchProfileFromDDL x20 y+5 w275, % GetProfilesList()
GuiControl, ChooseString, ActiveProfileDDL, %ActiveProfile%
Gui, Add, Button, gCreateProfile vCrtProf x20 y+5 w135, ➕ New Profile
Gui, Add, Button, gDeleteProfile vDelProf x+5 w135, ❌ Delete Profile

Gui, Add, Text, vMacroKeyPrompt x20 y+15 w300, Set macro hotkey:
Gui, Add, Hotkey, vUserHotkey gUpdateDisplay x20 y+5 w160,
Gui, Add, DropDownList, vUserHotkeyDDL gUpdateDisplay x+5 w90, %AltChoiceList%
SetAltChoice(UserHotkey, "UserHotkeyDDL")
Gui, Add, Checkbox, vUserHotkeyWildcard gUpdateDisplay x+10 w190, *Ignore other key presses (Ctrl, Alt, Shift)
Gui, Add, Text, vKeyPreviewText x20 y+0 w150, 

Gui, Add, Text, vStratPrompt x20 y+5 w270, Select stratagem:
Gui, Add, DropDownList, vSelectedStratagem x20 y+5 w460, ; % GetStratagemList()
Gui, Add, Button, gAddBinding vAddBtn x20 y+10 w150, Add Binding
Gui, Add, Button, gDeleteBinding vDeleteBtn x+5 w150, Delete Selected
Gui, Add, Button, gUpdateBinding vUpdateBtn x+5 w150, Update Selected

Gui, Add, ListView, vBindingsList x20 y+15 w460 h290 Grid BackgroundTrans, Hotkey|Stratagem
ReloadBindingsList()

; Settings (Tab, 2)
Gui, Tab, 2

Gui, Add, Text, vInputModePrompt x20 y+10 w190, ⌨️ Layout(Stratagem input):
Gui, Add, DropDownList, vInputMode gUpdateInputMode x20 y+5 w190, Arrows|WASD
GuiControl, ChooseString, InputMode, %InputMode%

Gui, Add, Text, vKeyPrompt x20 y+10, Select your Stratagem Menu Key:
Gui, Add, Hotkey, vActivationKeyInput x20 y+5 w95, %ActivationKey%
Gui, Add, DropDownList, vActivationKeyChoiceDDL x+5 w90, %AltChoiceList%
SetAltChoice(ActivationKey, "ActivationKeyChoiceDDL")
Gui, Add, Button, gApplyActivationKey vApplyKeyBtn x20 y+5 w190, Apply Key

Gui, Add, Edit, vActivationKeyDelayEdit Number x20 y+15 w40 gUpdateActivationKeyDelay, %ActivationKeyDelay%
Gui, Add, Text, vActKeyDelay x+5, Delay after Stratagem Menu Key (ms)
Gui, Add, Edit, vRealKeyDelayEdit Number x20 y+10 w40 gUpdateRealKeyDelay, %RealKeyDelay%
Gui, Add, Text, vPressKeyDelay x+5, Key Press Delay (ms)

Gui, Add, CheckBox, vAutoPauseActive gToggleAutoPause x20 y+25 Checked%AutoPauseActive%, ⏯️AUTO-PAUSE
Gui, Add, Edit, vAutoPauseTimerIntervalInput Number x20 y+5 w40 gUpdateAutoCheckTimer, %AutoPauseTimerInterval%
Gui, Add, Text, vAutoPauseTimerCheck x+5, Active Game Window Check Interval (ms)
Gui, Tab 

Gui, Show,, Stratagem Hotkey Manager Lite
AutoPauseCheckbox()

; Explicitly populate the stratagem list after GUI creation
GuiControl,, SelectedStratagem, | ; Clear it first
GuiControl,, SelectedStratagem, % GetStratagemList()
return

ShowGui:
Gui, Show
return

HideCustomGui:
Gui, Hide
return

CloseCustomGui:
ExitApp
return

StartMove:
PostMessage, 0xA1, 2,,, A ; WM_NCLBUTTONDOWN, HTCAPTION
return

ToggleSuspend:
Suspend
Return

LoadConfig() {
    global IniFile, InputMode, ActivationKey, ActiveProfile, DefaultProfile, ActivationKeyDelay, RealKeyDelay, AutoPauseActive
	IniRead, InputMode, %IniFile%, Config, InputMode, WASD
	IniRead, ActivationKey, %IniFile%, Config, ActivationKey, LControl
    IniRead, ActiveProfile, %IniFile%, Config, ActiveProfile, %DefaultProfile%
	IniRead, ActivationKeyDelay, %IniFile%, Config, ActivationKeyDelay, 25
	IniRead, RealKeyDelay, %IniFile%, Config, RealKeyDelay, 25
	IniRead, AutoPauseActive, %IniFile%, Config, AutoPauseActive, 0
	IniRead, AutoPauseTimerInterval, %IniFile%, Config, AutoPauseTimerInterval, 500
}

LoadBindings() {
    global Bindings, IniFile, ActiveProfile
    section := "Binds_" . ActiveProfile
    Bindings := Object()
    if !FileExist(IniFile)
        return
    IniRead, keysList, %IniFile%, %section%
    if (keysList != "ERROR") {
        Loop, Parse, keysList, `n, `r
        {
            if A_LoopField =
                continue
            StringSplit, Pair, A_LoopField, =
            key := Trim(Pair1)
            strat := Trim(Pair2)
            if (key != "" && strat != "") {
                Bindings[key] := strat
                Hotkey, %key%, StratagemHandler, On 
            }
        }
    }
}

UpdateInputMode:
Gui, Submit, NoHide
IniWrite, %InputMode%, %IniFile%, Config, InputMode
return

UpdateActivationKeyDelay:
    Gui, Submit, NoHide
    GuiControlGet, ActivationKeyDelay, , ActivationKeyDelayEdit
    If (ActivationKeyDelay < 0 || ActivationKeyDelay > 1000) {
        MsgBox, 16, % ("Error"), % ("Delay after menu key must be between 0 and 1000ms.")
        GuiControl,, ActivationKeyDelayEdit, 25
        ActivationKeyDelay := 25
    }
    IniWrite, %ActivationKeyDelay%, %IniFile%, Config, ActivationKeyDelay
return

UpdateRealKeyDelay:
    Gui, Submit, NoHide
    GuiControlGet, RealKeyDelay, , RealKeyDelayEdit
    If (RealKeyDelay < 0 || RealKeyDelay > 500) {
        MsgBox, 16,  % ("Error"), % ("Keystroke delay should be between 0 and 500ms.")
        GuiControl,, RealKeyDelayEdit, 25
        RealKeyDelay := 25
    }
    IniWrite, %RealKeyDelay%, %IniFile%, Config, RealKeyDelay
return

ApplyActivationKey:
Gui, Submit, NoHide
 if (ActivationKeyChoiceDDL != "[Input]") {
        NewActivationKey := ActivationKeyChoiceDDL
    } else {
        NewActivationKey := ActivationKeyInput
    }

    ActivationKey := NewActivationKey
    IniWrite, %ActivationKey%, %IniFile%, Config, ActivationKey

    MsgBox % ("Stratagem Menu Key: ") . ActivationKey
Return

UpdateDisplay()
{
    GuiControlGet, UserHotkey
    GuiControlGet, UserHotkeyWildcard
	GuiControlGet, UserHotkeyDDL, , UserHotkeyDDL
    shown := UserHotkey
	if (UserHotkeyDDL != "[Input]") {
    shown := UserHotkeyDDL
	} else {
    shown := UserHotkey
	}
    if (UserHotkeyWildcard)
        shown := "*" . shown
    GuiControl,, KeyPreviewText, % "Hotkey: " . shown
    return
}

AddBinding:
    Gui, Submit, NoHide
    finalUserHotkey := ""
    if (UserHotkeyDDL != "[Input]") {
        finalUserHotkey := UserHotkeyDDL
    } else {
        finalUserHotkey := UserHotkey
    }
    if (finalUserHotkey = "") {
        MsgBox % "Please input a hotkey."
        return
    }
    if (SelectedStratagem = "") {
        MsgBox % "Please select a stratagem."
        return
    }
    GuiControlGet, UserHotkeyWildcard
    bindKey := UserHotkeyWildcard ? "*" . finalUserHotkey : finalUserHotkey
    stratagemIdToBind := ""
    for id, nameStr in StratagemNames {
        if (nameStr = SelectedStratagem) {
            stratagemIdToBind := id
            break
        }
    }
    if (stratagemIdToBind = "") {
        MsgBox % "Error: Stratagem ID not found for '" . SelectedStratagem . "'"
        return
    }
	if (InStr(stratagemIdToBind, "category_") = 1 or InStr(stratagemIdToBind, "separator_") = 1) {
		MsgBox % "Error: Cannot bind categories or separators."
		return
	}
    Hotkey, %finalUserHotkey%, StratagemHandler, Off
    Hotkey, *%finalUserHotkey%, StratagemHandler, Off
    keysToDeactivateAndRemove := []
    for existingHotkey, _ in Bindings {
        if (existingHotkey = finalUserHotkey || existingHotkey = "*" . finalUserHotkey || existingHotkey = bindKey) {
            keysToDeactivateAndRemove.Push(existingHotkey)
        }
    }
    for _, key in keysToDeactivateAndRemove {
        Hotkey, %key%, StratagemHandler, Off ; Ensure it's off before deleting from our map.
        Bindings.Delete(key)
    }
    keysToDeleteExistingStratagemBinding := []
    for existingHotkey, existingStratID in Bindings {
        if (existingStratID = stratagemIdToBind && existingHotkey != bindKey) { ; Added existingHotkey != bindKey
            Hotkey, %existingHotkey%, StratagemHandler, Off
            keysToDeleteExistingStratagemBinding.Push(existingHotkey)
        }
    }
    for _, key in keysToDeleteExistingStratagemBinding {
        Bindings.Delete(key)
    }
    Bindings[bindKey] := stratagemIdToBind
    Hotkey, %bindKey%, StratagemHandler, On 
    SaveBindings()
    ReloadBindingsList()
Return

UpdateBinding:
    Gui, Submit, NoHide
    Row := LV_GetNext()
    if (!Row) {
        MsgBox % "Please select a binding to update."
        return
    }
    LV_GetText(visibleKey, Row, 1)
    LV_GetText(visibleStratagem, Row, 2)
    if (visibleKey = "") {
        MsgBox % "Cannot update category headers. Please select an actual binding."
        return
    }
    oldBindKey := KeyMap.HasKey(visibleKey) ? KeyMap[visibleKey] : visibleKey
    if (oldBindKey = "") {
        MsgBox % "Error: Could not find the original hotkey for the selected binding."
        return
    }
    newHotkeyInput := ""
    if (UserHotkeyDDL != "[Input]") {
        newHotkeyInput := UserHotkeyDDL
    } else {
        newHotkeyInput := UserHotkey
    }
    newStratagemName := SelectedStratagem
    updateHotkey := (newHotkeyInput != "")
    updateStratagem := (newStratagemName != "")
    if (!updateHotkey && !updateStratagem) {
        MsgBox % "Please input a new Hotkey and/or select a new Stratagem to update the binding."
        return
    }
    finalNewBindKey := oldBindKey
    finalNewStratID := Bindings[oldBindKey]
    if (updateHotkey) {
        GuiControlGet, UserHotkeyWildcard
        finalNewBindKey := UserHotkeyWildcard ? "*" . newHotkeyInput : newHotkeyInput
        bareKey := RegExReplace(finalNewBindKey, "^\*")
        wildcardKey := "*" . bareKey
        isConflict := (Bindings.HasKey(bareKey) && bareKey != oldBindKey) || (Bindings.HasKey(wildcardKey) && wildcardKey != oldBindKey)
        if (isConflict) {
            MsgBox % "Error: The hotkey '" . bareKey . "' is already in use by another binding."
            return
        }
    }
    if (updateStratagem) {
        newStratagemId := ""
        for id, nameStr in StratagemNames {
            if (nameStr = newStratagemName) {
                newStratagemId := id
                break
            }
        }
        if (newStratagemId = "") {
            MsgBox % "Error: Stratagem ID not found for '" . newStratagemName . "'"
            return
        }
        if (InStr(newStratagemId, "category_") = 1 or InStr(newStratagemId, "separator_") = 1) {
            MsgBox % "Error: Cannot bind categories or separators."
            return
        }
		for existingHotkey, existingStratID in Bindings {
            if (existingStratID = newStratagemId && existingHotkey != oldBindKey) {
                MsgBox % "Error: The stratagem '" . newStratagemName . "' is already bound to hotkey: " . existingHotkey . "."
                return
            }
        }
        finalNewStratID := newStratagemId
    }
    if (finalNewBindKey != oldBindKey) {
        Hotkey, %oldBindKey%, StratagemHandler, Off
        Bindings.Delete(oldBindKey)
    } 
    if (updateStratagem) {
         keysToDeleteExistingStratagemBinding := []
        for existingHotkey, existingStratID in Bindings {
            if (existingStratID = finalNewStratID && existingHotkey != finalNewBindKey) { 
                Hotkey, %existingHotkey%, StratagemHandler, Off
                keysToDeleteExistingStratagemBinding.Push(existingHotkey)
            }
        }
        for _, key in keysToDeleteExistingStratagemBinding {
            Bindings.Delete(key)
        }
    }
    Bindings[finalNewBindKey] := finalNewStratID
    Hotkey, %finalNewBindKey%, StratagemHandler, On 
    SaveBindings()
    ReloadBindingsList()
Return

DeleteBinding:
    Gui, Submit, NoHide
    Row := LV_GetNext()
    if (!Row) {
        MsgBox % "Please select a binding to delete."
        return
    }
    LV_GetText(visibleKey, Row, 1)
    HotkeyToDelete := KeyMap.HasKey(visibleKey) ? KeyMap[visibleKey] : visibleKey 
    if (HotkeyToDelete != "" && RegExMatch(HotkeyToDelete, "^\S+$")) {
        Hotkey, %HotkeyToDelete%, StratagemHandler, Off
        if (ErrorLevel) {
            MsgBox, 16, % ("Hotkey Deletion Error"), % ("Failed to deactivate hotkey: ") . HotkeyToDelete . "`n" . ("Error: ") . ErrorLevel
        }
    } else {
        MsgBox, 48, % ("Error"), % ("Invalid hotkey in list: '") . HotkeyToDelete . "'"
        return
    }
    Bindings.Delete(HotkeyToDelete)
    SaveBindings()
    ReloadBindingsList()
Return

ReloadBindingsList() {
    global Bindings, StratagemNames, KeyMap, OrderedStratagems

    GuiControl, -Redraw, BindingsList
    LV_Delete()
    KeyMap := {}

    categorizedBindings := Object() 
    currentCategory := ""
    for _, id in OrderedStratagems {
        if (InStr(id, "category_") = 1) {
            currentCategory := id
            categorizedBindings[currentCategory] := []
        } else if (InStr(id, "separator_") = 1) {
            continue
        } else {
            foundHotkey := ""
            for hotkey, boundStratID in Bindings {
                if (boundStratID = id) {
                    foundHotkey := hotkey
                    break
                }
            }
            if (foundHotkey != "") {
                if (IsObject(categorizedBindings[currentCategory])) {
                    categorizedBindings[currentCategory].Push({hotkey: foundHotkey, stratID: id})
                }
            }
        }
    }
    currentCategory := ""
    for _, id in OrderedStratagems {
        if (InStr(id, "category_") = 1) {
            currentCategory := id
            if (IsObject(categorizedBindings[currentCategory]) && categorizedBindings[currentCategory].Length() > 0) {
                LV_Add("", "", StratagemNames[id])
            }
        } else if (InStr(id, "separator_") = 1) {
            continue
        } else {
            if (IsObject(categorizedBindings[currentCategory])) {
                for _, bindingData in categorizedBindings[currentCategory] {
                    if (bindingData.stratID = id) {
                        keyUpper := Format("{:U}", bindingData.hotkey)
                        KeyMap[keyUpper] := bindingData.hotkey 
                        LV_Add("", keyUpper, StratagemNames[id])
                        break
                    }
                }
            }
        }
    }
    GuiControl, +Redraw, BindingsList
	GoSub, ClearInputFields
}

SaveBindings() {
    global Bindings, IniFile, ActiveProfile
    section := "Binds_" . ActiveProfile
    IniDelete, %IniFile%, %section%
    for key, strat in Bindings
        IniWrite, %strat%, %IniFile%, %section%, %key%
    IniWrite, %ActiveProfile%, %IniFile%, Config, ActiveProfile
}

ClearInputFields:
    GuiControl,, UserHotkey,
    GuiControl, Choose, UserHotkeyDDL, 1
    GuiControl, Choose, SelectedStratagem, 0
    GuiControl,, UserHotkeyWildcard, 0
    GuiControl,, KeyPreviewText, 
return

; === Profiles ===
LoadProfiles() {
    global Profiles, IniFile
    Profiles := []
    if !FileExist(IniFile)
        return
    Loop, Read, %IniFile%
    {
        if RegExMatch(A_LoopReadLine, "^\[Binds_(.+)\]$", m)
            Profiles.Push(m1)
    }
    if !Profiles.MaxIndex()
        Profiles.Push("Default")
}

GetProfilesList() {
    global IniFile
    list := ""
    profiles := Object()
    Loop, Read, %IniFile%
    {
        if RegExMatch(A_LoopReadLine, "^\[Binds_(.+)\]$", m)
            profiles[m1] := true
    }
    if !profiles.HasKey("Default")
        profiles["Default"] := true
    for profileName, _ in profiles
        list .= profileName . "|"
    return RTrim(list, "|")
}

; === Function to disable all active bindings ===
DeactivateAllBindings() {
    global Bindings
    for key, _ in Bindings {
        if (key != "") {
            Hotkey, %key%, Off
        }
    }
    Bindings := Object()
}

SwitchProfileFromDDL:
    Gui, Submit, NoHide
    GoSub, SwitchProfile
Return

SwitchProfile:
global ActiveProfileDDL
DeactivateAllBindings()
ActiveProfile := ActiveProfileDDL
IniWrite, %ActiveProfile%, %IniFile%, Config, ActiveProfile
IniRead, Dummy, %IniFile%, Binds_%ActiveProfile%
if (Dummy = "ERROR")
    IniWrite, Created, %IniFile%, Binds_%ActiveProfile%, Status
LoadBindings()
ReloadBindingsList()
GuiControl,, ActiveProfileDDL, |
GuiControl,, ActiveProfileDDL, % GetProfilesList()
GuiControl, ChooseString, ActiveProfileDDL, %ActiveProfile%
    ToolTipText := ("Active Profile: ") . ActiveProfile
    ToolTip, %ToolTipText%, A_ScreenWidth - 200, A_ScreenHeight - 50
    SetTimer, RemoveToolTip, -1000
return 

CreateProfile:
DeactivateAllBindings()
InputBox, NewProfileName, % ("New Profile"), % ("Enter a name for the new profile:")
if (NewProfileName = ""){
	LoadBindings() 
    return
	}
IniWrite, Created, %IniFile%, Binds_%NewProfileName%
ActiveProfile := NewProfileName
IniWrite, %ActiveProfile%, %IniFile%, Config, ActiveProfile
LoadProfiles()
GuiControl,, ActiveProfileDDL, |
GuiControl,, ActiveProfileDDL, % GetProfilesList()
GuiControl, ChooseString, ActiveProfileDDL, %ActiveProfile%
LoadBindings()
ReloadBindingsList()
MsgBox % ("New profile created: ") . ActiveProfile
return

DeleteProfile:
if (ActiveProfile = "Default") {
    MsgBox % ("Cannot delete the default profile!")
    return
}
DeactivateAllBindings()
IniDelete, %IniFile%, Binds_%ActiveProfile%
ActiveProfile := "Default"
IniWrite, %ActiveProfile%, %IniFile%, Config, ActiveProfile
LoadProfiles()
GuiControl,, ActiveProfileDDL, |
GuiControl,, ActiveProfileDDL, % GetProfilesList()
GuiControl, ChooseString, ActiveProfileDDL, %ActiveProfile%
LoadBindings()
ReloadBindingsList()
MsgBox % ("Profile deleted. Active profile: ") . ActiveProfile
return

GetStratagemList() {
    global OrderedStratagems, StratagemNames
    list := ""
    for _, id in OrderedStratagems {
        ; Check if it's a separator
        if (InStr(id, "separator_") > 0) {
            list .= StratagemNames[id] . "|"
        } else {
            list .= StratagemNames[id] . "|"
        }
    }
    return RTrim(list, "|")
}

; ====== Hotkey processing ======
StratagemHandler:
	global ActivationKeyDelay, ActivationKey
    ThisKey := A_ThisHotkey
    Stratagem := Bindings[ThisKey]
    if !Stratagem
        return

; --- Handle Weapon Modes ---	
if (Stratagem = "weapon_purifier_arc") {
        ; Execute Purifier/Arc-Thrower logic
		While GetKeyState(ThisKey, "P") {
        Send {LButton down}
        Sleep, 1050
        Send {LButton up}
        Sleep, 25
		}
        return
    } else if (Stratagem = "weapon_railgun_unsafe") {
        ; Execute Railgun Unsafe logic
        Send {LButton down}
        Sleep, 2940
        Send {LButton up}
        Sleep, 25
        Send {r down}
        Sleep, 25
        Send {r up}
        Sleep, 25
        return
    } else if (Stratagem = "weapon_epoch") {
        ; Execute Epoch logic
        Send {LButton down}
        Sleep, 2510
        Send {LButton up}
        Sleep, 25
        return
    }

; --- Handle Item Drop ---
if (Stratagem = "Iteam_drop_1") {
     Gosub, DIButton1Function
        return
    } else if (Stratagem = "Iteam_drop_2") {
    Gosub, DIButton2Function
        return
    } else if (Stratagem = "Iteam_drop_3") {
    Gosub, DIButton3Function
        return
    } else if (Stratagem = "Iteam_drop_4") {
    Gosub, DIButton4Function
        return
		}

; --- Handle Driver Assistant ---
if (Stratagem = "Gear_first") {
     Gosub, DA1Function
        return
    } else if (Stratagem = "Gear_reverse") {
    Gosub, DA2Function
        return
    }
	
; --- Stratagem Sequence Logic ---	
    Sequence := Stratagems[Stratagem]
    if !IsObject(Sequence) || Sequence.Length() = 0
        return

    SendInput, {%ActivationKey% Down}
    Sleep, ActivationKeyDelay
    ExecuteSequence(Sequence)
    SendInput, {%ActivationKey% Up}
return

; FUNCTION FOR ENTERING A SEQUENCE
ExecuteSequence(Sequence) {
    global InputMode, RealKeyDelay
    keyMap := (InputMode = "WASD")
        ? {Down:"s", Up:"w", Left:"a", Right:"d"}
        : {Down:"Down", Up:"Up",Left:"Left", Right:"Right"}

    for _, dir in Sequence {
        realKey := keyMap[dir]
        SendInput, {Blind}{%realKey% Down}
        Sleep, RealKeyDelay
        SendInput, {Blind}{%realKey% Up}
        Sleep, RealKeyDelay
    }
}

DIButton1Function:
    MouseMove, %center_x%, %center_y%, 0 ; центровка курсора
	PerformMouseMovement(-150, -150) ; перемещение курсора
	MouseMove, %center_x%, %center_y%, 0
Return

DIButton2Function:
    MouseMove, %center_x%, %center_y%, 0
	PerformMouseMovement(150, -150)
	MouseMove, %center_x%, %center_y%, 0
Return

DIButton3Function:
    MouseMove, %center_x%, %center_y%, 0
	PerformMouseMovement(-150, 150)
	MouseMove, %center_x%, %center_y%, 0
Return

DIButton4Function:
    MouseMove, %center_x%, %center_y%, 0
	PerformMouseMovement(150, 150)
	MouseMove, %center_x%, %center_y%, 0
Return

DA1Function:
    Loop 4
    {
        SendInput {Shift down}
        Sleep 25
        SendInput {Shift up}
        Sleep 25
    }
    SendInput {Ctrl down}
    Sleep 25
    SendInput {Ctrl up}
    Sleep 25
Return

DA2Function:
    Loop 4
    {
        SendInput {Ctrl down}
        Sleep 25
        SendInput {Ctrl up}
        Sleep 25
    }
Return

CalculateScreenCenter()
{
    SysGet, screen_width, 0
    SysGet, screen_height, 1

    center_x := screen_width / 2
    center_y := screen_height / 2
}

PerformMouseMovement(raw_move_x, raw_move_y)
{
    scale_x := screen_width / BASE_WIDTH
    scale_y := screen_height / BASE_HEIGHT

    scaled_move_x := raw_move_x * scale_x
    scaled_move_y := raw_move_y * scale_y

	Sleep 25
    Send {x Down}
    Sleep %DISleepDelay%
    MouseMove, %scaled_move_x%, %scaled_move_y%, 0, R
    Sleep %DISleepDelay2%
    Send {x Up}
}

AutoPauseCheckbox() {
    global AutoPauseActive 
    
    if (AutoPauseActive = 1) {
        GoSub, ToggleAutoPause
    }
    return
}

UpdateAutoCheckTimer:
    Gui, Submit, NoHide
    GuiControlGet, AutoPauseTimerInterval, , AutoPauseTimerIntervalInput
    If (AutoPauseTimerInterval < 0 || AutoPauseTimerInterval > 5000) {
        MsgBox, 16, Error, Active window check interval should be between 0 and 5000ms.
        GuiControl,, AutoPauseTimerIntervalInput, 500
        AutoPauseTimerInterval := 500
    }
    IniWrite, %AutoPauseTimerInterval%, %IniFile%, Config, AutoPauseTimerInterval
return

ToggleAutoPause:
    global AutoPauseActive, ScriptSuspended, AutoPauseTimerInterval

    GuiControlGet, AutoPauseActive, , AutoPauseActive 
    IniWrite, %AutoPauseActive%, %IniFile%, Config, AutoPauseActive
    
    if (AutoPauseActive)
    {
        SetTimer, AutoPauseCheck, %AutoPauseTimerInterval%
        ToolTip, AutoPause ON, A_ScreenWidth - 200, A_ScreenHeight - 50
    }
    else
    {
        SetTimer, AutoPauseCheck, Off
        
        if (A_IsSuspended)
        {
            global ScriptSuspended
            Suspend, % (ScriptSuspended ? "On" : "Off") 
        }
        ToolTip, AutoPause OFF, A_ScreenWidth - 200, A_ScreenHeight - 50
    }
    SetTimer, RemoveToolTip, -1000
    return

AutoPauseCheck:
    global ScriptSuspended

    IfWinActive, %GameTarget%
    {
        if (A_IsSuspended != ScriptSuspended) {
            Suspend, % (ScriptSuspended ? "On" : "Off")
            ToolTip, AutoPause Removed, A_ScreenWidth - 200, A_ScreenHeight - 50
            SetTimer, RemoveToolTip, -1000
        }
    }
    Else
    {
        if (!A_IsSuspended) 
        {
            Suspend, On
            ToolTip, AutoPause Active, A_ScreenWidth - 200, A_ScreenHeight - 50
            SetTimer, RemoveToolTip, -1000
        }
    }
return

; === Stratagems ===
LoadStratagems() {
    global Stratagems, StratagemNames, OrderedStratagems
    Stratagems := Object()
    StratagemNames := Object()
    OrderedStratagems := []

    ; === CATEGORY: Defensive Stratagems ===
    id := "category_defensive_stratagems"
    Stratagems[id] := []
    StratagemNames[id] := "--- Defensive Stratagems ---"
    OrderedStratagems.Push(id)

    id := "gatling_sentry"
    Stratagems[id] := ["Down", "Up", "Right", "Left"]
    StratagemNames[id] := "A/G-16 Gatling Sentry"
    OrderedStratagems.Push(id)

    id := "machine_sentry"
    Stratagems[id] := ["Down", "Up", "Right", "Right", "Up"]
    StratagemNames[id] := "A/MG-43 Machine Sentry"
    OrderedStratagems.Push(id)

    id := "flame_sentry"
    Stratagems[id] := ["Down", "Up", "Right", "Down", "Up", "Up"]
    StratagemNames[id] := "A/FLAM-40 Flame Sentry"
    OrderedStratagems.Push(id)
    
    id := "laser_sentry"
    Stratagems[id] := ["Down", "Up", "Right", "Down", "Up", "Right"]
    StratagemNames[id] := "A/LAS-98 Laser Sentry"
    OrderedStratagems.Push(id)

    id := "rocket_sentry"
    Stratagems[id] := ["Down", "Up", "Right", "Right", "Left"]
    StratagemNames[id] := "A/MLS-4X Rocket Sentry"
    OrderedStratagems.Push(id)

    id := "autocannon_sentry"
    Stratagems[id] := ["Down", "Up", "Right", "Up", "Left", "Up"]
    StratagemNames[id] := "A/AC-8 Autocannon Sentry"
    OrderedStratagems.Push(id)

    id := "ems_sentry"
    Stratagems[id] := ["Down", "Up", "Right", "Down", "Right"]
    StratagemNames[id] := "A/M-23 EMS Sentry"
    OrderedStratagems.Push(id)

    id := "mortar_sentry"
    Stratagems[id] := ["Down", "Up", "Right", "Right", "Down"]
    StratagemNames[id] := "A/M-12 Mortar Sentry"
    OrderedStratagems.Push(id)

    id := "shield_generator_relay"
    Stratagems[id] := ["Down", "Down", "Left", "Right", "Left", "Right"]
    StratagemNames[id] := "FX-12 Shield Generator Relay"
    OrderedStratagems.Push(id)

    id := "grenadier_battlement"
    Stratagems[id] := ["Down", "Right", "Down", "Left", "Right"]
    StratagemNames[id] := "E/GL-21 Grenadier Battlement"
    OrderedStratagems.Push(id)

    id := "anti_tank_emplacement"
    Stratagems[id] := ["Down", "Up", "Left", "Right", "Right", "Right"]
    StratagemNames[id] := "E/AT-12 Anti-Tank Emplacement"
    OrderedStratagems.Push(id)

    id := "hmg_emplacement"
    Stratagems[id] := ["Down", "Up", "Left", "Right", "Right", "Left"]
    StratagemNames[id] := "E/MG-101 HMG Emplacement"
    OrderedStratagems.Push(id)

    id := "tesla_tower"
    Stratagems[id] := ["Down", "Up", "Right", "Up", "Left", "Right"]
    StratagemNames[id] := "A/ARC-3 Tesla Tower"
    OrderedStratagems.Push(id)

    id := "anti_tank_mines"
    Stratagems[id] := ["Down", "Left", "Up", "Up"]
    StratagemNames[id] := "MD-17 Anti-Tank Mines"
    OrderedStratagems.Push(id)

    id := "gas_mines"
    Stratagems[id] := ["Down", "Left", "Left", "Right"]
    StratagemNames[id] := "MD-8 Gas Mines"
    OrderedStratagems.Push(id)

    id := "anti_personnel_minefield"
    Stratagems[id] := ["Down", "Left", "Up", "Right"]
    StratagemNames[id] := "MD-6 Anti-Personnel Minefield"
    OrderedStratagems.Push(id)

    id := "incendiary_mines"
    Stratagems[id] := ["Down", "Left", "Left", "Down"]
    StratagemNames[id] := "MD-14 Incendiary Mines"
    OrderedStratagems.Push(id)

    ; Separator
    id := "separator_1"
    Stratagems[id] := []
    StratagemNames[id] := " "
    OrderedStratagems.Push(id)

    ; === CATEGORY: Offensive Stratagems ===
    id := "category_offensive_stratagems"
    Stratagems[id] := []
    StratagemNames[id] := "--- Offensive Stratagems ---"
    OrderedStratagems.Push(id)

    id := "orbital_precision_strike"
    Stratagems[id] := ["Right", "Right", "Up"]
    StratagemNames[id] := "Orbital Precision Strike"
    OrderedStratagems.Push(id)

    id := "orbital_gatling_barrage"
    Stratagems[id] := ["Right", "Down", "Left", "Up", "Up"]
    StratagemNames[id] := "Orbital Gatling Barrage"
    OrderedStratagems.Push(id)

    id := "orbital_airburst_strike"
    Stratagems[id] := ["Right", "Right", "Right"]
    StratagemNames[id] := "Orbital Airburst Strike"
    OrderedStratagems.Push(id)

    id := "orbital_napalm_barrage"
    Stratagems[id] := ["Right", "Right", "Down", "Left", "Right", "Up"]
    StratagemNames[id] := "Orbital Napalm Barrage"
    OrderedStratagems.Push(id)

    id := "orbital_120mm_he_barrage"
    Stratagems[id] := ["Right", "Right", "Down", "Left", "Right", "Down"]
    StratagemNames[id] := "Orbital 120mm HE Barrage"
    OrderedStratagems.Push(id)

    id := "orbital_walking_barrage"
    Stratagems[id] := ["Right", "Down", "Right", "Down", "Right", "Down"]
    StratagemNames[id] := "Orbital Walking Barrage"
    OrderedStratagems.Push(id)

    id := "orbital_380mm_hs_barrage"
    Stratagems[id] := ["Right", "Down", "Up", "Up", "Left", "Down", "Down"]
    StratagemNames[id] := "Orbital 380mm HS Barrage"
    OrderedStratagems.Push(id)

    id := "orbital_rail_cannon_strike"
    Stratagems[id] := ["Right", "Up", "Down", "Down", "Right"]
    StratagemNames[id] := "Orbital Rail Cannon Strike"
    OrderedStratagems.Push(id)

    id := "orbital_laser"
    Stratagems[id] := ["Right", "Down", "Up", "Right", "Down"]
    StratagemNames[id] := "Orbital Laser"
    OrderedStratagems.Push(id)

    id := "orbital_ems_strike"
    Stratagems[id] := ["Right", "Right", "Left", "Down"]
    StratagemNames[id] := "Orbital EMS Strike"
    OrderedStratagems.Push(id)

    id := "orbital_gas_strike"
    Stratagems[id] := ["Right", "Right", "Down", "Right"]
    StratagemNames[id] := "Orbital Gas Strike"
    OrderedStratagems.Push(id)

    id := "orbital_smoke_strike"
    Stratagems[id] := ["Right", "Right", "Down", "Up"]
    StratagemNames[id] := "Orbital Smoke Strike"
    OrderedStratagems.Push(id)

    id := "eagle_500kg_bomb"
    Stratagems[id] := ["Up", "Right", "Down", "Down", "Down"]
    StratagemNames[id] := "Eagle 500kg Bomb"
    OrderedStratagems.Push(id)

    id := "eagle_strafing_run"
    Stratagems[id] := ["Up", "Right", "Right"]
    StratagemNames[id] := "Eagle Strafing Run"
    OrderedStratagems.Push(id)

    id := "eagle_110mm_rockets"
    Stratagems[id] := ["Up", "Right", "Up", "Left"]
    StratagemNames[id] := "Eagle 110mm Rockets"
    OrderedStratagems.Push(id)

    id := "eagle_airstrike"
    Stratagems[id] := ["Up", "Right", "Down", "Right"]
    StratagemNames[id] := "Eagle Airstrike"
    OrderedStratagems.Push(id)

    id := "eagle_cluster_bomb"
    Stratagems[id] := ["Up", "Right", "Down", "Down", "Right"]
    StratagemNames[id] := "Eagle Cluster Bomb"
    OrderedStratagems.Push(id)

    id := "eagle_napalm"
    Stratagems[id] := ["Up", "Right", "Down", "Up"]
    StratagemNames[id] := "Eagle Napalm"
    OrderedStratagems.Push(id)

    id := "eagle_smoke_strike"
    Stratagems[id] := ["Up", "Right", "Up", "Down"]
    StratagemNames[id] := "Eagle Smoke Strike"
    OrderedStratagems.Push(id)

    id := "eagle_re_arm"
    Stratagems[id] := ["Up", "Up", "Left", "Up", "Right"]
    StratagemNames[id] := "Eagle Re-arm"
    OrderedStratagems.Push(id)

    ; Separator
    id := "separator_2"
    Stratagems[id] := []
    StratagemNames[id] := " "
    OrderedStratagems.Push(id)

    ; === CATEGORY: Supply Stratagems ===
    id := "category_supply_stratagems"
    Stratagems[id] := []
    StratagemNames[id] := "--- Supply Stratagems ---"
    OrderedStratagems.Push(id)

    id := "cqc9_defoliation_tool"
    Stratagems[id] := ["Down", "Left", "Right", "Right", "Down"]
    StratagemNames[id] := "CQC-9 Defoliation Tool"
    OrderedStratagems.Push(id)
	
	id := "cqc1_one_true_flag"
    Stratagems[id] := ["Down", "Left", "Right", "Right", "Up"]
    StratagemNames[id] := "CQC-1 One True Flag"
    OrderedStratagems.Push(id)

    id := "mg43_machine_gun"
    Stratagems[id] := ["Down", "Left", "Down", "Up", "Right"]
    StratagemNames[id] := "MG-43 Machine Gun"
    OrderedStratagems.Push(id)

    id := "m105_stalwart"
    Stratagems[id] := ["Down", "Left", "Down", "Up", "Up", "Left"]
    StratagemNames[id] := "M-105 Stalwart"
    OrderedStratagems.Push(id)

    id := "mg206_heavy_machine_gun"
    Stratagems[id] := ["Down", "Left", "Up", "Down", "Down"]
    StratagemNames[id] := "MG-206 Heavy Machine Gun"
    OrderedStratagems.Push(id)

    id := "rs422_railgun"
    Stratagems[id] := ["Down", "Right", "Down", "Up", "Left", "Right"]
    StratagemNames[id] := "RS-422 Railgun"
    OrderedStratagems.Push(id)
	
	id := "s11_speargun"
    Stratagems[id] := ["Down", "Right", "Down", "Left", "Up", "Right"]
    StratagemNames[id] := "S-11 Speargun"
    OrderedStratagems.Push(id)

    id := "apw1_anti_material_rifle"
    Stratagems[id] := ["Down", "Left", "Right", "Up", "Down"]
    StratagemNames[id] := "APW-1 Anti-Material Rifle"
    OrderedStratagems.Push(id)
    
    id := "plas_45_epoch"
    Stratagems[id] := ["Down", "Left", "Up", "Left", "Right"]
    StratagemNames[id] := "PLAS-45 Epoch"
    OrderedStratagems.Push(id)

    id := "gl21_grenade_launcher"
    Stratagems[id] := ["Down", "Left", "Up", "Left", "Down"]
    StratagemNames[id] := "GL-21 Grenade Launcher"
    OrderedStratagems.Push(id)

    id := "gl52_de_escalator"
    Stratagems[id] := ["Down", "Right", "Up", "Left", "Right"]
    StratagemNames[id] := "GL-52 DE-ESCALATOR"
    OrderedStratagems.Push(id)

    id := "tx41_sterilizer"
    Stratagems[id] := ["Down", "Left", "Up", "Down", "Left"]
    StratagemNames[id] := "TX-41 Sterilizer"
    OrderedStratagems.Push(id)

    id := "flam40_flamethrower"
    Stratagems[id] := ["Down", "Left", "Up", "Down", "Up"]
    StratagemNames[id] := "FLAM-40 Flamethrower"
    OrderedStratagems.Push(id)

    id := "las98_laser_cannon"
    Stratagems[id] := ["Down", "Left", "Down", "Up", "Left"]
    StratagemNames[id] := "LAS-98 Laser Cannon"
    OrderedStratagems.Push(id)

    id := "las99_quasar_cannon"
    Stratagems[id] := ["Down", "Down", "Up", "Left", "Right"]
    StratagemNames[id] := "LAS-99 Quasar Cannon"
    OrderedStratagems.Push(id)

    id := "arc3_arc_thrower"
    Stratagems[id] := ["Down", "Right", "Down", "Up", "Left", "Left"]
    StratagemNames[id] := "ARC-3 Arc Thrower"
    OrderedStratagems.Push(id)

    id := "mls4x_commando"
    Stratagems[id] := ["Down", "Left", "Up", "Down", "Right"]
    StratagemNames[id] := "MLS-4X Commando"
    OrderedStratagems.Push(id)
	
	id := "eat700_expendable_napalm"
    Stratagems[id] := ["Down", "Down", "Left", "Up", "Left"]
    StratagemNames[id] := "EAT-700 Expendable Napalm"
    OrderedStratagems.Push(id)
	
	id := "ms11_solo_silo"
    Stratagems[id] := ["Down", "Up", "Right", "Down", "Down"]
    StratagemNames[id] := "MS-11 Solo Silo"
    OrderedStratagems.Push(id)

    id := "eat17_expendable_anti_tank"
    Stratagems[id] := ["Down", "Down", "Left", "Up", "Right"]
    StratagemNames[id] := "EAT-17 Expendable Anti-Tank"
    OrderedStratagems.Push(id)

    id := "ac8_autocannon"
    Stratagems[id] := ["Down", "Left", "Down", "Up", "Up", "Right"]
    StratagemNames[id] := "AC-8 Autocannon"
    OrderedStratagems.Push(id)

    id := "rl77_airburst_rocket_launcher"
    Stratagems[id] := ["Down", "Up", "Up", "Left", "Right"]
    StratagemNames[id] := "RL-77 Airburst Rocket Launcher"
    OrderedStratagems.Push(id)

    id := "faf14_spear_launcher"
    Stratagems[id] := ["Down", "Down", "Up", "Down", "Down"]
    StratagemNames[id] := "FAF-14 Spear Launcher"
    OrderedStratagems.Push(id)

    id := "sta_x3_wasp_launcher"
    Stratagems[id] := ["Down", "Down", "Up", "Down", "Right"]
    StratagemNames[id] := "StA-X3 W.A.S.P. Launcher"
    OrderedStratagems.Push(id)

    id := "m1000_maxigun"
    Stratagems[id] := ["Down", "Left", "Right", "Down", "Up", "Up"]
    StratagemNames[id] := "M-1000 Maxigun"
    OrderedStratagems.Push(id)
	
	id := "gr8_recoiless_rifle"
    Stratagems[id] := ["Down", "Left", "Right", "Right", "Left"]
    StratagemNames[id] := "GR-8 Recoiless Rifle"
    OrderedStratagems.Push(id)

    id := "b1_supply_pack"
    Stratagems[id] := ["Down", "Left", "Down", "Up", "Up", "Down"]
    StratagemNames[id] := "B-1 Supply Pack"
    OrderedStratagems.Push(id)

    id := "b100_portable_hellbomb"
    Stratagems[id] := ["Down", "Right", "Up", "Up", "Up"]
    StratagemNames[id] := "B-100 Portable Hellbomb"
    OrderedStratagems.Push(id)
    
    id := "lift182_warp_pack"
    Stratagems[id] := ["Down", "Left", "Right", "Down", "Left", "Right"]
    StratagemNames[id] := "LIFT-182 Warp Pack"
    OrderedStratagems.Push(id)

    id := "lift860_hover_pack"
    Stratagems[id] := ["Down", "Up", "Up", "Down", "Left", "Right"]
    StratagemNames[id] := "LIFT-860 Hover Pack"
    OrderedStratagems.Push(id)

    id := "lift850_jump_pack"
    Stratagems[id] := ["Down", "Up", "Up", "Down", "Up"]
    StratagemNames[id] := "LIFT-850 Jump Pack"
    OrderedStratagems.Push(id)

    id := "sh32_shield_generator_pack"
    Stratagems[id] := ["Down", "Up", "Left", "Right", "Left", "Right"]
    StratagemNames[id] := "SH-32 Shield Generator Pack"
    OrderedStratagems.Push(id)

    id := "sh51_directional_shield"
    Stratagems[id] := ["Down", "Up", "Left", "Right", "Up", "Up"]
    StratagemNames[id] := "SH-51 Directional Shield"
    OrderedStratagems.Push(id)

    id := "sh20_ballistic_shield_backpack"
    Stratagems[id] := ["Down", "Left", "Down", "Down", "Up", "Left"]
    StratagemNames[id] := "SH-20 Ballistic Shield Backpack"
    OrderedStratagems.Push(id)

    id := "guard_dog_k9"
    Stratagems[id] := ["Down", "Up", "Left", "Up", "Right", "Left"]
    StratagemNames[id] := "AX/ARC-3 Guard Dog K-9"
    OrderedStratagems.Push(id)

    id := "ax_flam75_guard_dog"
    Stratagems[id] := ["Down", "Up", "Left", "Up", "Left", "Left"]
    StratagemNames[id] := "AX/FLAM-75 Guard Dog Hot Dog"
    OrderedStratagems.Push(id)
	
	id := "ax_ar23_guard_dog"
    Stratagems[id] := ["Down", "Up", "Left", "Up", "Right", "Down"]
    StratagemNames[id] := "AX/AR-23 Guard Dog"
    OrderedStratagems.Push(id)

    id := "ax_las5_guard_dog_rover"
    Stratagems[id] := ["Down", "Up", "Left", "Up", "Right", "Right"]
    StratagemNames[id] := "AX/LAS-5 Guard Dog Rover"
    OrderedStratagems.Push(id)

    id := "ax_tx13_guard_dog_breath"
    Stratagems[id] := ["Down", "Up", "Left", "Up", "Right", "Up"]
    StratagemNames[id] := "AX/TX-13 Guard Dog Breath"
    OrderedStratagems.Push(id)

    id := "m102_fast_reconnaissance_vehicle"
    Stratagems[id] := ["Left", "Down", "Right", "Down", "Right", "Down", "Up"]
    StratagemNames[id] := "M-102 Fast Reconnaissance Vehicle"
    OrderedStratagems.Push(id)

    id := "exo49_emancipator_exosuit"
    Stratagems[id] := ["Left", "Down", "Right", "Up", "Left", "Down", "Up"]
    StratagemNames[id] := "EXO-49 Emancipator Exosuit"
    OrderedStratagems.Push(id)

    id := "exo45_patriot_exosuit"
    Stratagems[id] := ["Left", "Down", "Right", "Up", "Left", "Down", "Down"]
    StratagemNames[id] := "EXO-45 Patriot Exosuit"
    OrderedStratagems.Push(id)

    ; Separator
    id := "separator_3"
    Stratagems[id] := []
    StratagemNames[id] := " "
    OrderedStratagems.Push(id)

    ; === CATEGORY: Mission Stratagems ===
    id := "category_mission_stratagems"
    Stratagems[id] := []
    StratagemNames[id] := "--- Mission Stratagems ---"
    OrderedStratagems.Push(id)

    id := "reinforce"
    Stratagems[id] := ["Up", "Down", "Right", "Left", "Up"]
    StratagemNames[id] := "Reinforce"
    OrderedStratagems.Push(id)

    id := "resupply"
    Stratagems[id] := ["Down", "Down", "Up", "Right"]
    StratagemNames[id] := "Resupply"
    OrderedStratagems.Push(id)

    id := "nux223_hellbomb"
    Stratagems[id] := ["Down", "Up", "Left", "Down", "Up", "Right", "Down", "Up"]
    StratagemNames[id] := "NUX-223 Hellbomb"
    OrderedStratagems.Push(id)

    id := "super_earth_flag"
    Stratagems[id] := ["Down", "Up", "Down", "Up"]
    StratagemNames[id] := "Super Earth Flag"
    OrderedStratagems.Push(id)

    id := "sos_beacon"
    Stratagems[id] := ["Up", "Down", "Right", "Up"]
    StratagemNames[id] := "SOS Beacon"
    OrderedStratagems.Push(id)

    id := "sssd_delivery"
    Stratagems[id] := ["Down", "Down", "Down", "Up", "Up"]
    StratagemNames[id] := "SSSD Delivery"
    OrderedStratagems.Push(id)

    id := "seismic_probe"
    Stratagems[id] := ["Up", "Up", "Left", "Right", "Down", "Down"]
    StratagemNames[id] := "Seismic Probe"
    OrderedStratagems.Push(id)

    id := "upload_data"
    Stratagems[id] := ["Left", "Right", "Up", "Up", "Up"]
    StratagemNames[id] := "Upload Data"
    OrderedStratagems.Push(id)

    id := "prospecting_drill"
    Stratagems[id] := ["Down", "Down", "Left", "Right", "Down", "Down"]
    StratagemNames[id] := "Prospecting Drill"
    OrderedStratagems.Push(id)

    id := "dark_fluid_vessel"
    Stratagems[id] := ["Up", "Left", "Right", "Down", "Up", "Up"]
    StratagemNames[id] := "Dark Fluid Vessel"
    OrderedStratagems.Push(id)

    id := "tectonic_drill"
    Stratagems[id] := ["Up", "Down", "Up", "Down", "Up", "Down"]
    StratagemNames[id] := "Tectonic Drill"
    OrderedStratagems.Push(id)

    id := "hive_breaker_drill"
    Stratagems[id] := ["Left", "Up", "Down", "Right", "Down", "Down"]
    StratagemNames[id] := "Hive Breaker Drill"
    OrderedStratagems.Push(id)
	
	id := "mobile_extraction_drill"
    Stratagems[id] := ["Down", "Down", "Left", "Left", "Down", "Down"]
    StratagemNames[id] := "Mobile Extraction Drill"
    OrderedStratagems.Push(id)

    id := "seaf_artillery"
    Stratagems[id] := ["Right", "Up", "Up", "Down"]
    StratagemNames[id] := "SEAF Artillery"
    OrderedStratagems.Push(id)
	
	; Separator
    id := "separator_4"
    Stratagems[id] := []
    StratagemNames[id] := " "
    OrderedStratagems.Push(id)
	
	; === CATEGORY: Weapon Modes ===
    id := "category_weapon_modes"
    Stratagems[id] := []
    StratagemNames[id] := "--- Weapon Assistant ---"
    OrderedStratagems.Push(id)

    id := "weapon_purifier_arc"
    Stratagems[id] := ["Purifier"]
    StratagemNames[id] := "Purifier/Arc-Thrower"
    OrderedStratagems.Push(id)

    id := "weapon_railgun_unsafe"
    Stratagems[id] := ["RailgunUnsafe"]
    StratagemNames[id] := "Railgun (Unsafe)"
    OrderedStratagems.Push(id)
    
    id := "weapon_epoch"
    Stratagems[id] := ["Epoch"]
    StratagemNames[id] := "Epoch"
    OrderedStratagems.Push(id)
    
    ; Separator
    id := "separator_5"
    Stratagems[id] := []
    StratagemNames[id] := " "
    OrderedStratagems.Push(id)
    
    ; === CATEGORY: Item Drop ===
    id := "category_item_drop"
    Stratagems[id] := []
    StratagemNames[id] := "--- Item Drop ---"
    OrderedStratagems.Push(id)

    id := "Iteam_drop_1"
    Stratagems[id] := ["DropItem1"]
    StratagemNames[id] := "Drop Backpack ↖"
    OrderedStratagems.Push(id)

    id := "Iteam_drop_2"
    Stratagems[id] := ["DropItem2"]
    StratagemNames[id] := "Drop Weapon ↗"
    OrderedStratagems.Push(id)

    id := "Iteam_drop_3"
    Stratagems[id] := ["DropItem3"]
    StratagemNames[id] := "Drop Suitcase ↙"
    OrderedStratagems.Push(id)
    
    id := "Iteam_drop_4"
    Stratagems[id] := ["DropItem4"]
    StratagemNames[id] := "Drop Samples ↘"
    OrderedStratagems.Push(id)
	
	; Separator
    id := "separator_6"
    Stratagems[id] := []
    StratagemNames[id] := " "
    OrderedStratagems.Push(id)
	
	; === CATEGORY: Driver Assistant ===
    id := "category_driver_assistant"
    Stratagems[id] := []
    StratagemNames[id] := "--- Driver Assistant ---"
    OrderedStratagems.Push(id)

    id := "Gear_first"
    Stratagems[id] := ["GearSwitch1"]
    StratagemNames[id] := "First Gear"
    OrderedStratagems.Push(id)

    id := "Gear_reverse"
    Stratagems[id] := ["GearSwitch2"]
    StratagemNames[id] := "Reverse Gear"
    OrderedStratagems.Push(id)
}

GuiClose:
ExitApp

ReloadScript:
Reload
return

*End::
Suspend, Permit
ExitApp
return

*Insert::
Suspend
ToolTip,% a_isSuspended?"Script is off":"Script is on", 1400, 2800
SetTimer, RemoveToolTip, -2000
return

RemoveToolTip:
ToolTip
return