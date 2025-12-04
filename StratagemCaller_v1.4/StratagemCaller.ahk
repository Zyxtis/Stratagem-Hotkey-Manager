#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%
#SingleInstance force
#Persistent
SetMouseDelay, -1 ; For Weapon Assistant

; --- Global Variables for Stratagem Manager ---
global Stratagems := Object()
global StratagemNames := Object()
global OrderedStratagems := []
global Bindings := Object()
global ActivationKey := "LControl"
global Language := "English"
global InputMode := "Arrows"
global IniFile := A_ScriptDir . "\Settings.ini"
global ActiveProfile := ""
global DefaultProfile := "Default"
global SuspendHotkey := "Insert"
global ExitHotkey := "End"
global ScriptSuspended := false
global CurrentActivationMode := 5
global ActivationModeNames := Object()
ActivationModeNames.ru := ["Быстро нажать", "Быстро нажать дважды", "Нажать", "Долгое нажатие", "Удерживать"]
ActivationModeNames.en := ["Tap", "Double Tap", "Press", "Long Press", "Hold"]
global ActivationKeyDelay := 25     ; Задержка после нажатия ActivationKey
global RealKeyDelay := 25          ; Задержка между Down и Up для realKey
global ActiveProfileDDL
global ProfileNextHotkey, ProfilePrevHotkey
global AutoPauseActive
global AutoPauseTimerInterval := 500 
GameTarget := "HELLDIVERS™ 2"

; --- Глобальные переменные для разрешения экрана (вычисляются один раз) ---
global screen_width, screen_height, center_x, center_y
global BASE_WIDTH := 1920
global BASE_HEIGHT := 1080
; Определить где центр экрана
CalculateScreenCenter()

; --- Global Variables for Weapon Assistant ---
Global WeaponAssistantActive := false
Global WeaponAssistHotkey := "LButton"
Global CurrentWeaponMode := 1 ; 0-Purifier | 1-Railgun Safe | 2-Railgun Unsafe
Global UnsafeChargePercent := 100 ; 16-100 %
; --- Global Variables for Driver Assistant ---
Global DriverAssistantActive := false
Global LastKey := ""
; --- Global Variables for Inventory Function ---
global DISleepDelay := 25
global DISleepDelay2 := 75

Global WeaponModeNames := Object()
WeaponModeNames.ru := ["Очиститель/Дуговой-метатель"
                     ,"Рельсотрон (Обычный)"
                     ,"Рельсотрон (Убойный)"
					 ,"Эпоха"]
WeaponModeNames.en := ["Purifier/Arc-Thrower"
                     ,"Railgun (Safe)"
                     ,"Railgun (Unsafe)"
					 ,"Epoch"]

Global ToggleWeaponHotkey := ""
Global CycleWeaponModeHotkey := ""
Global DriverAssistHotkey := ""

Global CurrentTheme := "light" ; Инициализируем тему по умолчанию
global KeyMap := {} ; keyUpper => keyOriginal

; Добавляем кнопки мышки и поле [Input] для DropDownList
; Определим массив с элементами в нужном порядке
AltKeys := ["LControl", "RControl", "LShift", "RShift", "LAlt", "RAlt", "LWin", "RWin", "Tab", "XButton1", "XButton2", "MButton", "WheelUp", "WheelDown", "LButton", "RButton"]
; Создаем строку для выпадающего списка, итерируя по этому массиву
AltChoiceList := "[Input]" ; Первый элемент в списке
for index, key in AltKeys
    AltChoiceList .= "|" . key

; Удаляем символы * и ~ в начале строки с хоткеев для возврата в gui
StripWildcard(hotkey) {
    if (SubStr(hotkey, 1, 1) = "*" or SubStr(hotkey, 1, 1) = "~") {
        return SubStr(hotkey, 2)
    }
    return hotkey
}
; --- Добавляем * если отмечен чекбокс ---
ApplyWildcard(hotkey, wildcardFlag) {
    return (wildcardFlag && hotkey != "") ? "*" . StripWildcard(hotkey) : StripWildcard(hotkey)
}
	
; --- Assistant Hotkey check and return ---
SetAltChoice(hotkeyValue, controlName) {
    global AltKeys
	hotkeyValue := StripWildcard(hotkeyValue)
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
	
; === Load Settings ===
LoadAllSettings()
LoadWPHotkeys()
LoadDISettings()
LoadFloatingGuiPosition()

; ---------- GUI ----------
Gui, Color, % (CurrentTheme = "dark" ? "0x222222" : "0xffffff")
Gui, Font, % (CurrentTheme = "dark" ? "c9c9c9c s11" : "cBlack s11")
Gui, Margin, 10, 10
Gui, Add, Button, gToggleScriptButton vToggleScriptBtn x430 y3 w90 h35
Gui, Add, Progress, vScriptStatusIndicator x+5 w20 h20 cGreen, ; Индикатор цвета (Progress Bar)
Gui, Add, Tab2, vMainTab gMainTabChange x10 y15 w550 h760, % (Language = "Русский" ? "Главная|Настройки|Ассистент" : "Main|Settings|Assistant")

; === Tab 1: Main (Stratagem Manager) ===
Gui, Tab, 1
Gui, Add, Text, vCustomProf x25 y+15 w270, 📂 Профиль:
Gui, Add, DropDownList, vActiveProfileDDL gSwitchProfileFromDDL x25 y+5 w315, % GetProfilesList()
GuiControl, ChooseString, ActiveProfileDDL, %ActiveProfile%
Gui, Add, Button, gCreateProfile vCrtProf x25 y+10 w155, ➕ Новый профиль
Gui, Add, Button, gDeleteProfile vDelProf x+5 w155, ❌ Удалить профиль

Gui, Add, Text, vMacroKeyPrompt x25 y+15 w300, Установите горячую клавишу для макроса:
Gui, Add, Hotkey, vUserHotkey gUpdateDisplay x25 y+5 w120
Gui, Add, DropDownList, vUserHotkeyDDL gUpdateDisplay x+5 w100, %AltChoiceList%
SetAltChoice(UserHotkey, "UserHotkeyDDL")
Gui, Add, Checkbox, vUserHotkeyWildcard gUpdateDisplay x+10 w265, % (Language = "Русский" ? "* любой модификатор" : "* any modificator")
Gui, Add, Text, vKeyPreviewText x25 y+10 w200, 

Gui, Add, Text, vStratPrompt x25 y+5 w270, Выберите стратагему:
Gui, Add, DropDownList, vSelectedStratagem x25 y+5 w520, ; % GetStratagemList()
Gui, Add, Button, gAddBinding vAddBtn x25 y+10 w170, Добавить привязку
Gui, Add, Button, gDeleteBinding vDeleteBtn x+5 w170, Удалить выбранное
Gui, Add, Button, gUpdateBinding vUpdateBtn x+5 w170, Обновить выбранное

Gui, Add, ListView, vBindingsList x25 y+15 w520 h440 Grid, % (Language = "Русский" ? "Клавиша|Стратагема|ID" : "Hotkey|Stratagem|ID")
ReloadBindingsList()
Gui, Tab

; === Tab 2: Settings (Stratagem Manager) ===
Gui, Tab, 2
Gui, Add, Text, vLangPrompt x25 y+15 w140, 🌐 Выберите язык:
Gui, Add, DropDownList, vLanguage gSwitchLanguage x25 y+5 w170, English|Русский
GuiControl, ChooseString, Language, %Language%

Gui, Add, Text, vInputModePrompt x25 y+10 w240, ⌨️ Раскладка:
Gui, Add, DropDownList, vInputMode gUpdateInputMode x25 y+5 w170, Arrows|WASD
GuiControl, ChooseString, InputMode, %InputMode%

Gui, Add, Text, vActivationModePromt x25 y+10 w260, Тип ввода(клавиши меню стратагем):
Gui, Add, DropDownList, vSelectedActivationMode x25 y+5 w170 gOnModeChange

Gui, Add, Text, vKeyPrompt x25 y+10 w280, Выберите вашу клавишу Меню Стратагем:
Gui, Add, Hotkey, vActivationKeyInput x25 y+5 w85, %ActivationKey%
Gui, Add, DropDownList, vActivationKeyChoiceDDL x+5 w80, %AltChoiceList%
SetAltChoice(ActivationKey, "ActivationKeyChoiceDDL")
Gui, Add, Button, gApplyActivationKey vApplyKeyBtn x25 y+5 w170, Применить клавишу

Gui, Add, Hotkey, vSuspendHotkeyControl x25 y+20 w170
Gui, Add, Text, vSuspendKeyPrompt x+5 w220, Клавиша вкл/выкл скрипт

Gui, Add, Hotkey, vExitHotkeyControl x25 y+10 w170
Gui, Add, Text, vExitKeyPrompt x+5 w220, Клавиша закрыть скрипт

Gui, Add, Hotkey, vFloatingHotkeyControl x25 y+10 w170, %FloatingWindowHotkey%
Gui, Add, Text, vApplyFloatingHotkey x+5 w220, Клавиша для Плавающего окна

; --- Горячая клавиша "Следующий профиль" ---
Gui, Add, Hotkey, vProfileNextHotkeyControl x25 y+10 w170, %ProfileNextHotkey%
Gui, Add, Text, vProfileNextPrompt x+5 w220, Клавиша Следующий профиль

; --- Горячая клавиша "Предыдущий профиль" ---
Gui, Add, Hotkey, vProfilePrevHotkeyControl x25 y+10 w170, %ProfilePrevHotkey%
Gui, Add, Text, vProfilePrevPrompt x+5 w220, Клавиша Предыдущий профиль

Gui, Add, Button, gApplyAllHotkeys vApplyAllHotkeysBtn x25 y+10 w170, Применить клавиши

; ---  элементы управления для задержек ---
Gui, Add, Text, vKeyDelays x25 y+20 w320, Настройки задержек ввода стратагем:
Gui, Add, Edit, vActivationKeyDelayEdit Number x25 y+5 w40 gUpdateActivationKeyDelay, %ActivationKeyDelay%
Gui, Add, Text, vActKeyDelay x+5 w320, Задержка после клавиши Меню Стратагем (мс)

Gui, Add, Edit, vRealKeyDelayEdit Number x25 y+10 w40 gUpdateRealKeyDelay, %RealKeyDelay%
Gui, Add, Text, vPressKeyDelay x+5 w300, Задержка нажатий клавиш (мс)

Gui, Add, Text, vThemePrompt w120 x25 y+20, % (Language = "Русский" ? "Смена темы:" : "Change Theme:")
Gui, Add, Button, gToggleThemeButton vToggleThemeBtn x25 y+5 w100, % (Language = "Русский" ? (CurrentTheme = "dark" ? "Светлая тема" : "Тёмная тема") : (CurrentTheme = "dark" ? "Light Theme" : "Dark Theme"))

Gui, Add, Text, vFloatingWindowPrompt x25 y+15 w160, % (Language = "Русский" ? "Плавающий список:" : "Floating List:")
Gui, Add, Button, gToggleFloatingWindowButton vToggleFloatingWindowBtn x25 y+5 w100, % (Language = "Русский" ? (FloatingGuiVisible ? "Спрятать" : "Показать") : (FloatingGuiVisible ? "Hide" : "Show"))

Gui, Add, Text, vFloatingOpacityPromt x25 y+10 w240, Прозрачность плавающего списка:
Gui, Add, Slider, vFloatingOpacitySlider Range0-255 ToolTip w150 gUpdateOpacity, %FloatingGuiOpacity%

Gui, Add, Text, vFloatingVisibility x300 y570, Настройки видимости(Cкрыть):
; Получаем список категорий из OrderedStratagems
uniqueCategories := Object()
for index, stratID_or_Category in OrderedStratagems {
    if (InStr(stratID_or_Category, "category_") = 1) {
        uniqueCategories[stratID_or_Category] := true
    }
}
; Добавляем чекбоксы для каждой категории
for categoryID in uniqueCategories {
    ; Используем имя переменной vHidden_%categoryID% для каждой категории
    Gui, Add, Checkbox, x300 y+2 vHidden_%categoryID% gUpdateFloatingListSetting, % StratagemNames[categoryID][Language]
}
; Добавим чекбокс для скрытия названий категорий и разделителей
Gui, Add, Checkbox, x300 y+2 w220 vHideCategoryNames gUpdateFloatingListSetting, % (Language = "Русский" ? "Названия категорий" : "Category names")
Gui, Add, Checkbox, x300 y+2 w220 vHiddenSeparator gUpdateFloatingListSetting, % (Language = "Русский" ? "Разделители" : "Separators")
Gui, Add, Checkbox, x300 y+2 w240 vHidden_Assistants gUpdateFloatingListSetting, % (Language = "Русский" ? "Скрыть Ассистент" : "Hide Assistant")

GuiControl,, ActivationKeyList, %ActivationKey%
GuiControl,, ActivationKeyHotkey, %ActivationKey%
GuiControl,, SuspendHotkeyControl, %SuspendHotkey%
GuiControl,, ExitHotkeyControl, %ExitHotkey%
GuiControl, ChooseString, InputMode, %InputMode%

Gui, Add, CheckBox, vAutoPauseActive gToggleAutoPause x300 y75 Checked%AutoPauseActive%, ⏯️Автоматическая пауза
Gui, Add, Text, vAutoPauseTimerCheck x300 y+10 w250, Проверка активного окна игры:
Gui, Add, Edit, vAutoPauseTimerIntervalInput Number x300 y+5 w40 gUpdateAutoCheckTimer, %AutoPauseTimerInterval%
Gui, Add, Text, vAutoPauseTimerCheckTime x+5 w90, (мс)
Gui, Tab

; === Tab 3: Assistant ===
Gui, Tab, 3
Gui, Add, Text, vWPStatusLabel x25 y+15 w125, % (Language = "Русский" ? "Ассистент Оружия:" : "Weapon Assistant:")
Gui, Add, Text, vWPStatusText x+5 w270,
Gui, Add, Text, vDAStatusLabel x25 y+5 w125, % (Language = "Русский" ? "Ассист Вождения:" : "Driver Assistant:")
Gui, Add, Text, vDAStatusText x+5 w270,

Gui, Add, Text, vWPModeLabel x25 y+10 w270, % (Language = "Русский" ? "Выберите режим оружия:" : "Select Weapon Mode:")
Gui, Add, DropDownList, vWPSelectedMode gWPModeChanged w165

Gui, Add, Edit, vWPChargePercentInput x25 y+10 w60 Number
Gui, Add, UpDown, Range16-100 0x80 gWPUnsafeChargeChanged
Gui, Add, Text, vWPUnsafeChargeLabel w240 x+5, % (Language = "Русский" ? "Заряд Рельсотрона (Убойный) (%)" : "Railgun(Unsafe) Charge (%)")

Gui, Add, Hotkey, vWPToggleScriptInput x25 y+15, % StripWildcard(ToggleWeaponHotkey)
Gui, Add, DropDownList, vWPButton1MouseChoice x+5 w100, %AltChoiceList%
Gui, Add, Checkbox, vWPToggleWildcard x+5 Checked%WPToggleWildcard%, *
SetAltChoice(ToggleWeaponHotkey, "WPButton1MouseChoice")
Gui, Add, Text, vWPHotkeyToggleLabel x+5 w210, % (Language = "Русский" ? "(Ассистент Оружия)" : "(On/Off Weapon Assistant)")

Gui, Add, Hotkey, vWPWeaponAssistInput x25 y+10, % StripWildcard(WeaponAssistHotkey)
Gui, Add, DropDownList, vWPWeaponAssistMouseChoice x+5 w100, %AltChoiceList%
Gui, Add, Checkbox, vWPWeaponAssistWildcard x+5 Checked%WPWeaponAssistWildcard%, *
SetAltChoice(WeaponAssistHotkey, "WPWeaponAssistMouseChoice")
Gui, Add, Text, vWPLButtonLabel x+5 w210, % (Language = "Русский" ? "(Выстрел)" : "(Fire Button)")

Gui, Add, Hotkey, vWPSafetyHotkeyInput x25 y+10, % StripWildcard(SafetyHotkey)
Gui, Add, DropDownList, vWPSafetyMouseChoice x+5 w100, %AltChoiceList%
Gui, Add, Checkbox, vWPSafetyWildcard x+5 Checked%WPSafetyWildcard%, ~
SetAltChoice(SafetyHotkey, "WPSafetyMouseChoice")
Gui, Add, Text, vWPSafetyHotkeyLabel x+5 w210, % (Language = "Русский" ? "(Предохранитель)" : "(Safety Catch)")

Gui, Add, Hotkey, vWPCycleModeInput x25 y+10, % StripWildcard(CycleWeaponModeHotkey)
Gui, Add, DropDownList, vWPButton2MouseChoice x+5 w100, %AltChoiceList%
Gui, Add, Checkbox, vWPCycleWildcard x+5 Checked%WPCycleWildcard%, *
SetAltChoice(CycleWeaponModeHotkey, "WPButton2MouseChoice")
Gui, Add, Text, vWPHotkeyCycleLabel x+5 w210, % (Language = "Русский" ? "(Переключение Режимов)" : "(Weapon Mode Switching)")

Gui, Add, Hotkey, vWPDriverAssistHotkeyControl x25 y+10, % StripWildcard(DriverAssistHotkey)
Gui, Add, DropDownList, vWPButton3MouseChoice x+5 w100, %AltChoiceList%
Gui, Add, Checkbox, vWPDriverWildcard x+5 Checked%WPDriverWildcard%, *
SetAltChoice(DriverAssistHotkey, "WPButton3MouseChoice")
Gui, Add, Text, vWPHotkeyDriverLabel x+5 w210, % (Language = "Русский" ? "(Ассистент Вождения)" : "Hotkey (On/Off Driver Assistant)")
Gui, Add, Button, gSaveWPSettings vWPApplyWeaponSettings x25 y+10 w165, % (Language = "Русский" ? "Применить настройки" : "Apply Settings")

Gui, Add, Text, vDILabel x25 y+15 w270, Инвентарь менеджер:
Gui, Add, Hotkey, vDIButton1Input x25 y+10, %DIButton1Hotkey%
Gui, Add, DropDownList, vDIButton1MouseChoice x+5 w100, %AltChoiceList%
Gui, Add, Checkbox, vDIButton1Wildcard x+5 Checked%DIButton1Wildcard%, *
Gui, Add, Text, vDIHotkey1 x+5 w200, (Скинуть Рюкзак)
SetAltChoice(DIButton1Hotkey, "DIButton1MouseChoice")

Gui, Add, Hotkey, vDIButton2Input x25 y+10, %DIButton2Hotkey%
Gui, Add, DropDownList, vDIButton2MouseChoice x+5 w100, %AltChoiceList%
Gui, Add, Checkbox, vDIButton2Wildcard x+5 Checked%DIButton2Wildcard%, * 
Gui, Add, Text, vDIHotkey2 x+5 w200, (Выбросить Оружие)
SetAltChoice(DIButton2Hotkey, "DIButton2MouseChoice")

Gui, Add, Hotkey, vDIButton3Input x25 y+10, %DIButton3Hotkey%
Gui, Add, DropDownList, vDIButton3MouseChoice x+5 w100, %AltChoiceList%
Gui, Add, Checkbox, vDIButton3Wildcard x+5 Checked%DIButton3Wildcard%, *
Gui, Add, Text, vDIHotkey3 x+5 w200, (Выбросить Кейс)
SetAltChoice(DIButton3Hotkey, "DIButton3MouseChoice")

Gui, Add, Hotkey, vDIButton4Input x25 y+10, %DIButton4Hotkey%
Gui, Add, DropDownList, vDIButton4MouseChoice x+5 w100, %AltChoiceList%
Gui, Add, Checkbox, vDIButton4Wildcard x+5 Checked%DIButton4Wildcard%, *
Gui, Add, Text, vDIHotkey4 x+5 w200, (Выбросить Образцы)
SetAltChoice(DIButton4Hotkey, "DIButton4MouseChoice")

Gui, Add, Text, vDIDelayLabel x25 y+10 w460, Задержка (мс) после нажатия и отпусканием клавиши (X):
Gui, Add, Edit, vDISleepDelayInput Number x25 y+5 w50, %DISleepDelay%
Gui, Add, Edit, vDISleepDelayInput2 Number x+5 w50, %DISleepDelay2%
Gui, Add, Button, gSaveDISettings vDIApplySettings x25 y+5 w165, Сохранить и применить
Gui, Tab

SetUIText(Language)
InitWeaponGUIControls() ; Initialize Weapon Assistant GUI controls
UpdateWeaponStatus() ; Update Weapon Assistant Status
UpdateDriverStatus()
InitActivationModeGUIControls()

; Explicitly populate the stratagem list after GUI creation
GuiControl,, SelectedStratagem, | ; Clear it first
GuiControl,, SelectedStratagem, % GetStratagemList()

SetSuspendHotkey()
SetExitHotkey()
ScriptSuspended := A_IsSuspended ; Initialize script suspension state
UpdateToggleButtonText() ; Update the main toggle button text on startup
LoadFloatingListSettings()
Gui, Show,, Stratagem Hotkey Manager
AutoPauseCheckbox() ; AutoPauseCheck
return

; === UI Update (Stratagem Manager & Weapon Assistant) ===
SetUIText(lang) {
	 global CurrentTheme ; For the theme-specific button text
    ; Update Stratagem Manager GUI text
    GuiControl,, CustomProf, % (lang = "Русский" ? "📂 Профиль:" : "📂 Profile:")
    GuiControl,, CrtProf, % (lang = "Русский" ? "➕ Новый профиль" : "➕ New Profile")
    GuiControl,, DelProf, % (lang = "Русский" ? "❌ Удалить профиль" : "❌ Delete Profile")
	
	GuiControl,, MacroKeyPrompt, % (lang = "Русский" ? "Установите горячую клавишу для макроса:" : "Set macro hotkey:")
	GuiControl,, UserHotkeyWildcard, % (lang = "Русский" ? "* Игнорировать нажатия (Ctrl, Alt, Shift)" : "* Ignore held modifier keys (Ctrl, Alt, Shift)")
	
	GuiControl,, StratPrompt, % (lang = "Русский" ? "Выберите Стратагему:" : "Select Stratagem:")
    GuiControl,, AddBtn, % (lang = "Русский" ? "Добавить привязку" : "Add Binding")
    GuiControl,, DeleteBtn, % (lang = "Русский" ? "Удалить выбранное" : "Delete Selected")
	GuiControl,, UpdateBtn, % (lang = "Русский" ? "Обновить выбранное" : "Update Selected")
	
    GuiControl,, LangPrompt, % (lang = "Русский" ? "🌐 Выберите язык:" : "🌐 Select Language:")
	GuiControl,, AutoPauseActive, % (lang = "Русский" ? "⏯️ АВТО-ПАУЗА" : "⏯️ AUTO-PAUSE")
	GuiControl,, AutoPauseTimerCheck, % (lang = "Русский" ? "Проверка активного окна игры:" : "Active Game Window Check:")
	GuiControl,, AutoPauseTimerCheckTime, % (lang = "Русский" ? "(мс) интервал" : "(ms) interval")
	
    GuiControl,, InputModePrompt, % (lang = "Русский" ? "⌨️ Раскладка(Ввода стратагем):" : "⌨️ Layout(Stratagem input):")
	GuiControl,, ActivationModePromt, % (lang = "Русский" ? "Тип ввода(клавиши меню стратагем):" : "Input type(stratagem menu key):")
    
	GuiControl,, KeyPrompt, % (lang = "Русский" ? "Выберите вашу клавишу Меню Стратагем:" : "Select your Stratagem Menu key:")
    GuiControl,, ApplyKeyBtn, % (lang = "Русский" ? "Применить клавишу" : "Apply Key")
	
    GuiControl,, KeyDelays, % (lang = "Русский" ? "Настройки задержек ввода стратагем:" : "Stratagem Input Delay Settings:")
	GuiControl,, ActKeyDelay, % (lang = "Русский" ? "Задержка после клавиши Меню Стратагем (мс)" : "Delay after Stratagem Menu Key (ms)")
    GuiControl,, PressKeyDelay, % (lang = "Русский" ? "Задержка нажатий клавиш (мс)" : "Key Press Delay (ms)")
    
    GuiControl,, SuspendKeyPrompt, % (lang = "Русский" ? "(Клавиша вкл/выкл скрипт)" : "(Toggle Script Hotkey)")
	GuiControl,, ExitKeyPrompt, % (lang = "Русский" ? "(Клавиша закрыть скрипт)" : "(Exit Script Hotkey)")
	GuiControl,, ApplyFloatingHotkey, % (lang = "Русский" ? "(Клавиша для Плавающего окна)" : "(Floating Window Hotkey)")
	GuiControl,, ProfileNextPrompt, % (Language = "Русский" ? "(Клавиша Следующий профиль)" : "(Next Profile Hotkey)")
	GuiControl,, ProfilePrevPrompt, % (Language = "Русский" ? "(Клавиша Предыдущий профиль)" : "(Previous Profile Hotkey)")
	GuiControl,, ApplyAllHotkeysBtn, % (Language = "Русский" ? "Применить клавиши" : "Apply keys")
	
	GuiControl,, ThemePrompt, % (lang = "Русский" ? "Смена темы:" : "Change Theme:")
	GuiControl,, ToggleThemeBtn, % (lang = "Русский" ? (CurrentTheme = "dark" ? "Светлая тема" : "Тёмная тема") : (CurrentTheme = "dark" ? "Light Theme" : "Dark Theme"))
	GuiControl,, FloatingWindowPrompt, % (Language = "Русский" ? "Плавающий список:" : "Floating List:")
	GuiControl,, ToggleFloatingWindowBtn, % (lang = "Русский" ? (FloatingGuiVisible ? "Спрятать" : "Показать") : (FloatingGuiVisible ? "Hide" : "Show"))
	GuiControl,, FloatingOpacityPromt, % (Language = "Русский" ? "Прозрачность плавающего списка:" : "Floating List Transparency:")
	GuiControl,, FloatingVisibility, % (Language = "Русский" ? "Настройки видимости(скрыть):" : "Visibility Settings(check to hide):")
	GuiControl,, HideCategoryNames, % (Language = "Русский" ? "Скрыть названия категорий" : "Hide category names")
	GuiControl,, HiddenSeparator, % (Language = "Русский" ? "Убрать разделители" : "Remove separators")
	GuiControl,, Hidden_Assistants, % (Language = "Русский" ? "Скрыть Активные Ассистенты" : "Hide Active Assistants")

    ; Update Weapon Assistant GUI text
    GuiControl,, WPStatusLabel, % (Language = "Русский" ? "Ассистент Оружия:" : "Weapon Assistant:")
	GuiControl,, DAStatusLabel, % (Language = "Русский" ? "Ассист Вождения:" : "Driver Assistant:")
    GuiControl,, WPModeLabel, % (Language = "Русский" ? "Выберите режим оружия:" : "Select Weapon Mode:")
    GuiControl,, WPUnsafeChargeLabel, % (Language = "Русский" ? "Заряд Рельсотрона (Убойный) (%)" : "Railgun(Unsafe) Charge (%)")
    GuiControl,, WPHotkeyToggleLabel, % (Language = "Русский" ? "(Ассистент Оружия вкл/выкл)" : "(On/Off Weapon Assistant)")
    GuiControl,, WPHotkeyCycleLabel, % (Language = "Русский" ? "(Переключение Режимов)" : "(Weapon Mode Switching)")
    GuiControl,, WPHotkeyDriverLabel, % (Language = "Русский" ? "(Ассистент Вождения вкл/выкл)" : "(On/Off Driver Assistant)")
	GuiControl,, WPApplyWeaponSettings, % (Language = "Русский" ? "Применить настройки" : "Apply Settings")
	
	; Update Drop Inventory GUI text
	GuiControl,, DILabel, % (Language = "Русский" ? "Инвентарь менеджер, клавиша(X):" : "Inventory Manager, key(X):")
	GuiControl,, DIHotkey1, % (Language = "Русский" ? "(Скинуть Рюкзак) ↖" : "(Drop Backpack) ↖")
	GuiControl,, DIHotkey2, % (Language = "Русский" ? "(Выбросить Оружие) ↗" : "(Drop Weapon) ↗")
	GuiControl,, DIHotkey3, % (Language = "Русский" ? "(Выбросить Кейс) ↙" : "(Drop Suitcase) ↙")
	GuiControl,, DIHotkey4, % (Language = "Русский" ? "(Выбросить Образцы) ↘" : "(Drop Samples) ↘")
	GuiControl,, DIDelayLabel, % (Language = "Русский" ? "Задержка (мс) после нажатия клавиши(X) и перед её отпусканием:" : "Delay (ms) after pressing key(X) and before releasing it :")
	GuiControl,, DIApplySettings, % (Language = "Русский" ? "Сохранить и применить" : "Save Settings and Apply")

    ; Update dropdowns that depend on language
    GuiControl,, SelectedStratagem, | ; <-- Clear the stratagem dropdown first!
    GuiControl,, SelectedStratagem, % GetStratagemList() ; <-- Then populate with new list

    LV_ModifyCol(1, "100 Text", Language = "Русский" ? "Клавиша" : "Hotkey")
    LV_ModifyCol(2, "410 Text", Language = "Русский" ? "Стратагема" : "Stratagem")
	LV_ModifyCol(3, "0")
    ReloadBindingsList()
    
    ; Выбираем нужный элемент из уже обновленного списка режимов оружия
    GuiControl, Choose, WPSelectedMode, % WeaponModeNames[lang = "Русский" ? "ru" : "en"][CurrentWeaponMode]
    InitActivationModeGUIControls() 
    UpdateWeaponStatus() ; Update Weapon Assistant status text
	UpdateDriverStatus()
	GuiControl,, MainTab, |
	GuiControl,, MainTab, % (lang = "Русский" ? "Главная|Настройки|Ассистент" : "Main|Settings|Assistant")
    UpdateToggleButtonText() ; Update main script toggle button
}

; ====== Плавающее окно и горячая клавиша HOME ======
global FloatingGuiVisible := false
global FloatingWindowHotkey := "Home"
global FloatingGuiX := 100
global FloatingGuiY := 100
global FloatingGuiCreated := false
global FloatingGuiOpacity := 128

LoadAllSettings()
{
    global IniFile, Language, ActiveProfile, ActivationKey, SuspendHotkey, ExitHotkey, SavedInputMode, SavedActivationMode
    global CurrentWeaponMode, UnsafeChargePercent, WeaponAssistantActive, CurrentTheme, AutoPauseActive, AutoPauseTimerInterval
	
    ; Stratagem Manager Settings
    IniRead, Language, %IniFile%, Config, Language, English
	IniRead, AutoPauseActive, %IniFile%, Config, AutoPauseActive, 0
	IniRead, AutoPauseTimerInterval, %IniFile%, Config, AutoPauseTimerInterval, 500
    IniRead, ActiveProfile, %IniFile%, Config, ActiveProfile, Default
    IniRead, ActivationKey, %IniFile%, Config, ActivationKey, LControl
	IniRead, ActivationKeyDelay, %IniFile%, Config, ActivationKeyDelay, 25
	IniRead, RealKeyDelay, %IniFile%, Config, RealKeyDelay, 25
    IniRead, SuspendHotkey, %IniFile%, Config, SuspendHotkey, Insert
	IniRead, ExitHotkey, %IniFile%, Config, ExitHotkey, End
    IniRead, SavedInputMode, %IniFile%, Config, InputMode, Arrows
    InputMode := SavedInputMode
	IniRead, CurrentTheme, %IniFile%, Config, CurrentTheme, light ; THEME TOGGLE CHANGE: Read CurrentTheme from INI
	
	IniRead, CurrentActivationMode, %IniFile%, Config, CurrentActivationMode, 5 ; По умолчанию 5 (Hold)
    
    if (CurrentActivationMode < 1 || CurrentActivationMode > ActivationModeNames.en.Length()) {
        CurrentActivationMode := 5 ; Устанавливаем значение по умолчанию, если прочитанное невалидно
    }

	; --- Загрузка горячих клавиш переключения профилей при запуске скрипта ---
	IniRead, ProfileNextHotkey, %IniFile%, Config, ProfileNextHotkey, PgUp
	ProfileNextHotkey := Trim(ProfileNextHotkey) 
	IniRead, ProfilePrevHotkey, %IniFile%, Config, ProfilePrevHotkey, PgDn
	ProfilePrevHotkey := Trim(ProfilePrevHotkey)
	; --- Инициализируем (включаем) горячие клавиши при запуске скрипта ---
	SetProfileSwitchHotkeys()
	; --- Загрузка горячих клавиш плавающего окна ---
	IniRead, FloatingWindowHotkey, %IniFile%, Config, FloatingWindowHotkey, Home
	SetFloatingWindowHotkey()

    ; Weapon Assistant Settings
    IniRead, CurrentWeaponMode, %IniFile%, WeaponSettings, CurrentWeaponMode, 1
    IniRead, UnsafeChargePercent, %IniFile%, WeaponSettings, UnsafeChargePercent, 100
    ; WeaponAssistantActive is volatile and not saved, it starts as false
    LoadStratagems(Language) ; Load stratagems after language is known
    LoadBindings() ; Load stratagem bindings
}

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
    GuiControl,, KeyPreviewText, % (Language = "Русский" ? "Клавиша: " : "Hotkey: ") . shown
    return
}

; --- THEME TOGGLE CHANGE: G-label for theme button ---
ToggleThemeButton:
    global CurrentTheme
    ; Toggle the theme state
    if (CurrentTheme = "light") {
        CurrentTheme := "dark"
    } else {
        CurrentTheme := "light"
    }  
    ; Apply the new theme (this will save it to INI)
    ApplyTheme(CurrentTheme)
    ; Reload the script to apply the new GUI theme fully
    Reload
Return

; --- THEME TOGGLE CHANGE: apply theme and save to INI ---
ApplyTheme(theme) {
    global CurrentTheme, IniFile, Language
    ; Save the selected theme to the INI file
    IniWrite, %theme%, %IniFile%, Config, CurrentTheme
    ; Update global variable
    CurrentTheme := theme
    ; Update the text of the theme button
    GuiControl,, ToggleThemeBtn, % (Language = "Русский" ? (CurrentTheme = "dark" ? "Светлая тема" : "Тёмная тема") : (CurrentTheme = "dark" ? "Light Theme" : "Dark Theme"))
}

; === TAB Change Handler ===
MainTabChange:
    Gui, Submit, NoHide
    If A_GuiControl = MainTab
    {
        ; Additional logic if needed when changing tabs
    }
return

; --- Language Switching ---
SwitchLanguage:
    Gui, Submit, NoHide
    ; Получаем выбранное значение из DDL на вкладке Settings
    GuiControlGet, SelectedLanguage,, Language ; 'Language' here refers to the vLanguage control name
    Language := SelectedLanguage
    IniWrite, %Language%, %IniFile%, Config, Language
    
    ; Теперь вызываем SetUIText для обновления всех текстов без перезагрузки
    SetUIText(Language)
    
    ; Обновляем список стратагем после смены языка
    LoadStratagems(Language)
    ReloadBindingsList() ; Убедимся, что ListView также обновлен
    
    ; Обновляем список режимов оружия и выбираем текущий
    InitWeaponGUIControls() ; Переиспользуем InitWeaponGUIControls для обновления DropDownList
    UpdateToggleButtonText()
	InitActivationModeGUIControls()
	; Обновляем плавающее окно
	UpdateFloatingWindow()
Return

UpdateInputMode:
Gui, Submit, NoHide
IniWrite, %InputMode%, %IniFile%, Config, InputMode
MsgBox % (Language = "Русский" ? "Раскладка установлен на: " : "Layout set to: ") . InputMode
return

OnModeChange:
    Gui, Submit, NoHide
    Loop, 5
    if (SelectedActivationMode = ActivationModeNames[Language = "Русский" ? "ru" : "en"][A_Index])
    CurrentActivationMode := A_Index
	IniWrite, %CurrentActivationMode%, %IniFile%, Config, CurrentActivationMode
	MsgBox % (Language = "Русский" ? "Тип ввода установлен на: " : "Input type set to: ") . SelectedActivationMode
return

UpdateActivationKeyDelay:
    Gui, Submit, NoHide
    GuiControlGet, ActivationKeyDelay, , ActivationKeyDelayEdit
    If (ActivationKeyDelay < 0 || ActivationKeyDelay > 1000) { ; Ограничиваем разумными пределами
        MsgBox, 16, % (Language="Русский" ? "Ошибка" : "Error"), % (Language="Русский" ? "Задержка после клавиши меню стратагем должна быть от 0 до 1000мс." : "Delay after Stratagem Menu key must be between 0 and 1000ms.")
        GuiControl,, ActivationKeyDelayEdit, 25 ; Возвращаем к значению по умолчанию
        ActivationKeyDelay := 25
    }
    IniWrite, %ActivationKeyDelay%, %IniFile%, Config, ActivationKeyDelay
return

UpdateRealKeyDelay:
    Gui, Submit, NoHide
    GuiControlGet, RealKeyDelay, , RealKeyDelayEdit
    If (RealKeyDelay < 0 || RealKeyDelay > 500) { ; Ограничиваем разумными пределами
        MsgBox, 16,  % (Language="Русский" ? "Ошибка" : "Error"), % (Language="Русский" ? "Задержка нажатий клавиш должна быть от 0 до 500мс." : "Keystroke delay should be between 0 and 500ms.")
        GuiControl,, RealKeyDelayEdit, 25 ; Возвращаем к значению по умолчанию
        RealKeyDelay := 25
    }
    IniWrite, %RealKeyDelay%, %IniFile%, Config, RealKeyDelay
return

UpdateAutoCheckTimer:
    Gui, Submit, NoHide
    GuiControlGet, AutoPauseTimerInterval, , AutoPauseTimerIntervalInput
    If (AutoPauseTimerInterval < 0 || AutoPauseTimerInterval > 5000) { ; Ограничиваем разумными пределами
        MsgBox, 16,  % (Language="Русский" ? "Ошибка" : "Error"), % (Language="Русский" ? "Задержка между проверками должна быть от 0 до 5000мс." : "Active window check interval should be between 0 and 5000ms.")
        GuiControl,, AutoPauseTimerIntervalInput, 500 ; Возвращаем к значению по умолчанию
        AutoPauseTimerInterval := 500
    }
    IniWrite, %AutoPauseTimerInterval%, %IniFile%, Config, AutoPauseTimerInterval
return

; === ActivationKey Application (Stratagem Manager) ===
ApplyActivationKey:
Gui, Submit, NoHide
 if (ActivationKeyChoiceDDL != "[Input]") {
        NewActivationKey := ActivationKeyChoiceDDL
    } else {
        NewActivationKey := ActivationKeyInput
    }

    ActivationKey := NewActivationKey
    IniWrite, %ActivationKey%, %IniFile%, Config, ActivationKey

    MsgBox % (Language = "Русский" ? "Клавиша Меню Стратагем: " : "Stratagem Menu Key: ") . ActivationKey
Return

GetStratagemList() {
    global OrderedStratagems, StratagemNames, Language
    list := ""
    for _, id in OrderedStratagems {
        ; Check if it's a separator
        if (InStr(id, "separator_") > 0) {
            list .= StratagemNames[id][Language] . "|"
        } else {
            list .= StratagemNames[id][Language] . "|"
        }
    }
    return RTrim(list, "|")
}

; === Bindings ===
AddBinding:
    Gui, Submit, NoHide
    
    ; Determine the final hotkey, preferring DDL if "[Input]" is not selected
    finalUserHotkey := ""
    if (UserHotkeyDDL != "[Input]") { ; Check if a specific hotkey was selected from DDL
        finalUserHotkey := UserHotkeyDDL
    } else { ; Otherwise, use the manually entered hotkey
        finalUserHotkey := UserHotkey
    }

    if (finalUserHotkey = "") {
        MsgBox % (Language = "Русский" ? "Пожалуйста, введите или выберите горячую клавишу." : "Please input or select a hotkey.")
        return
    }
    
    if (SelectedStratagem = "") {
        MsgBox % (Language = "Русский" ? "Пожалуйста, выберите стратагему." : "Please select a stratagem.")
        return
    }

    ; Get wildcard status and construct the bindKey
    GuiControlGet, UserHotkeyWildcard
    bindKey := UserHotkeyWildcard ? "*" . finalUserHotkey : finalUserHotkey
    
    ; --- Find the stratagem ID based on the selected stratagem name ---
    stratagemIdToBind := ""
    for id, nameObj in StratagemNames { ; nameObj is {English: Name, Русский: Name}
        if (nameObj[Language] = SelectedStratagem) {
            stratagemIdToBind := id
            break
        }
    }
    
    ; Error check if stratagem ID wasn't found
    if (stratagemIdToBind = "") {
        MsgBox % (Language = "Русский" ? "Ошибка: ID стратагемы не найден для '" : "Error: Stratagem ID not found for '") . SelectedStratagem . "'"
        return
    }
	; Error check to prevent binding categories and separators
	if (InStr(stratagemIdToBind, "category_") = 1 or InStr(stratagemIdToBind, "separator_") = 1) {
		MsgBox % (Language="Русский" ? "Ошибка: Нельзя привязать категории или разделители." : "Error: Cannot bind categories or separators.")
		return
}

    ; Disable and remove any EXISTING hotkeys associated with THIS specific stratagem
    for hotkeyToRemove, existingStratID in Bindings {
        if (existingStratID = stratagemIdToBind) { ; If this stratagem is already bound to another key
            ; Disable the old hotkey
            Hotkey, %hotkeyToRemove%, StratagemHandler, Off
            ; Remove it from the Bindings object
            Bindings.Delete(hotkeyToRemove)
            
            ; Remove it from KeyMap, ONE hotkey for a stratagem to be reflected in KeyMap
            KeyUpperToRemove := Format("{:U}", hotkeyToRemove)
            if (KeyMap.HasKey(KeyUpperToRemove)) {
                KeyMap.Delete(KeyUpperToRemove)
            }
        }
    }
    
    ; Disable and remove any EXISTING bindings for the NEW hotkey being assigned
    Hotkey, %finalUserHotkey%, StratagemHandler, Off
    Hotkey, *%finalUserHotkey%, StratagemHandler, Off
    for key, id in Bindings {
        if (key = finalUserHotkey || key = "*" . finalUserHotkey) {
            Bindings.Delete(key)
        }
    }

    ; Add the new binding
    Bindings[bindKey] := stratagemIdToBind

    ; Activate the new hotkey
    Hotkey, %bindKey%, StratagemHandler, On 
    
    ; Save and refresh all GUIs
    SaveBindings()
    ReloadBindingsList()
    UpdateFloatingList()
Return

DeleteBinding:
    Gui, Submit, NoHide
    Row := LV_GetNext()
    if (!Row) {
        MsgBox % Language = "Русский" ? "Пожалуйста, выберите привязку для удаления." : "Please select a binding to delete."
        return
    }
    
    LV_GetText(selectedTextCol1, Row, 1) ; Текст из первого столбца (может быть пустой для категории)
    LV_GetText(hiddenIdData, Row, 3)     ; Данные из третьего, скрытого столбца (ID стратагемы или CAT_IDкатегории)

    if (InStr(hiddenIdData, "CAT_") = 1) { ; Пользователь выбрал заголовок категории
        categoryToDeleteID := SubStr(hiddenIdData, 5) ; Извлекаем ID категории (после "CAT_")
        
        ; Подтверждение удаления всей категории
        MsgBox, 4, % (Language = "Русский" ? "Подтверждение удаления категории" : "Confirm Category Deletion"), % (Language = "Русский" ? "Вы уверены, что хотите удалить ВСЕ привязки в категории '" : "Are you sure you want to delete ALL bindings in category '") . StratagemNames[categoryToDeleteID][Language] . "'?"
        IfMsgBox, No
            return

        ; Собираем все стратагемы, которые принадлежат этой категории
        stratagemsToDeleteInThisCategory := Object()
        currentCategoryScopeActive := false
        
        ; Проходим по OrderedStratagems, чтобы найти все стратагемы в выбранной категории
        for index, currentID_in_Ordered in OrderedStratagems {
            if (currentID_in_Ordered = categoryToDeleteID) { ; Нашли начало выбранной категории
                currentCategoryScopeActive := true
                continue ; Пропускаем саму категорию, начинаем сканировать следующую
            }
            if (currentCategoryScopeActive) {
                if (InStr(currentID_in_Ordered, "category_") = 1) { ; Нашли следующую категорию, значит эта закончилась
                    break ; Выходим из цикла
                }
                ; Если это не категория и не разделитель, то это стратагема в текущей категории
                if (!InStr(currentID_in_Ordered, "separator_") = 1) { 
                    stratagemsToDeleteInThisCategory[currentID_in_Ordered] := true ; Добавляем ID стратагемы в список для удаления
                }
            }
        }

        ; Теперь проходим по Bindings и удаляем все привязки, связанные с найденными стратагемами
        ; Используем копию Bindings, чтобы безопасно удалять элементы во время итерации
        bindingsCopy := Object()
        for k, v in Bindings
            bindingsCopy[k] := v

        for hotkey, stratID in bindingsCopy {
            if (stratagemsToDeleteInThisCategory.HasKey(stratID)) { ; Если эта стратагема принадлежит удаляемой категории
                Hotkey, %hotkey%, StratagemHandler, Off ; Отключаем хоткей
                Bindings.Delete(hotkey)                  ; Удаляем из Bindings
                
                ; Удаляем из KeyMap (если там хранится)
                KeyUpperToRemove := Format("{:U}", hotkey)
                if (KeyMap.HasKey(KeyUpperToRemove)) {
                    KeyMap.Delete(KeyUpperToRemove)
                }
            }
        }

    } else { ; Пользователь выбрал обычную привязку (не категорию)
        HotkeyToDelete := KeyMap.HasKey(selectedTextCol1) ? KeyMap[selectedTextCol1] : selectedTextCol1 ; Получаем точный хоткей из KeyMap

        ; Базовая валидация
        if (HotkeyToDelete != "" && RegExMatch(HotkeyToDelete, "^\S+$")) {
            Hotkey, %HotkeyToDelete%, StratagemHandler, Off
            if (ErrorLevel) {
                MsgBox, 16, % (Language = "Русский" ? "Ошибка удаления Hotkey" : "Hotkey Deletion Error"), % (Language = "Русский" ? "Не удалось деактивировать горячую клавишу: " : "Failed to deactivate hotkey: ") . HotkeyToDelete . "`n" . (Language = "Русский" ? "Ошибка: " : "Error: ") . ErrorLevel
            }
        } else {
            MsgBox, 48, % (Language = "Русский" ? "Ошибка" : "Error"), % (Language = "Русский" ? "Некорректная горячая клавиша в списке: '" : "Invalid hotkey in list: '") . HotkeyToDelete . "'"
            return
        }

        ; Удаляем из Bindings.
        Bindings.Delete(HotkeyToDelete)
        
        ; Удаляем из KeyMap
        KeyUpperToRemove := Format("{:U}", HotkeyToDelete)
        if (KeyMap.HasKey(KeyUpperToRemove)) {
            KeyMap.Delete(KeyUpperToRemove)
        }
    }
    
    SaveBindings()
    ReloadBindingsList()
    UpdateFloatingWindow()
Return

UpdateBinding:
    Gui, Submit, NoHide
    
    Row := LV_GetNext()
    if (!Row) {
        MsgBox % (Language = "Русский" ? "Пожалуйста, выберите привязку для обновления." : "Please select a binding to update.")
        return
    }
    
    LV_GetText(visibleKey, Row, 1)          ; Клавиша
    LV_GetText(visibleStratagem, Row, 2)    ; Стратагема
    
    ; 1. Проверка: Выбрана ли рабочая привязка
    if (visibleKey = "") {
        MsgBox % (Language = "Русский" ? "Нельзя обновить заголовок категории. Выберите привязку." : "Cannot update category headers. Please select an actual binding.")
        return
    }
    
    ; 2. Определение старого хоткея и валидация
    oldBindKey := KeyMap.HasKey(visibleKey) ? KeyMap[visibleKey] : visibleKey ; Фактический старый хоткей (*F1)
    if (!Bindings.HasKey(oldBindKey)) { 
        MsgBox % (Language = "Русский" ? "Ошибка: Не удалось найти исходную горячую клавишу для выбранной привязки." : "Error: Could not find the original hotkey for the selected binding.")
        return
    }
    
    ; 3. Определение новой клавиши, стратагемы и флагов обновления
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
        MsgBox % (Language = "Русский" ? "Введите новую клавишу и/или выберите новую Стратагему для обновления привязки." : "Please input a new Hotkey and/or select a new Stratagem to update the binding.")
        return
    }
    
    ; Инициализация финальных значений
    finalNewBindKey := oldBindKey
    finalNewStratID := Bindings[oldBindKey]
    
    ; --- I. ПРОВЕРКА И ОБНОВЛЕНИЕ КЛАВИШИ ---
    if (updateHotkey) {
        GuiControlGet, UserHotkeyWildcard
        finalNewBindKey := UserHotkeyWildcard ? "*" . newHotkeyInput : newHotkeyInput
        
        bareKey := RegExReplace(finalNewBindKey, "^\*")
        wildcardKey := "*" . bareKey
        
        ; Определяем, какой из двух форм (bareKey или wildcardKey) конфликтует
        conflictKey := ""
        
        ; Проверяем, конфликтует ли bareKey И не является ли это текущей привязкой (oldBindKey)
        if (Bindings.HasKey(bareKey) && bareKey != oldBindKey) { 
            conflictKey := bareKey
        } 
        ; Проверяем, конфликтует ли wildcardKey И не является ли это текущей привязкой (oldBindKey)
        else if (Bindings.HasKey(wildcardKey) && wildcardKey != oldBindKey) { 
            conflictKey := wildcardKey
        }

        if (conflictKey != "") {
            ; Получаем информацию о конфликтующей стратагеме ---
            conflictingStratagemId := Bindings[conflictKey]
            
            ; Получаем имя стратагемы на текущем языке
            conflictingStratagemName := StratagemNames.HasKey(conflictingStratagemId) 
                ? (IsObject(StratagemNames[conflictingStratagemId]) ? StratagemNames[conflictingStratagemId][Language] : StratagemNames[conflictingStratagemId])
                : (Language="Русский" ? "Неизвестная Стратагема" : "Unknown Stratagem")

            MsgBox, 16, % (Language="Русский" ? "Ошибка привязки" : "Binding Error"), 
        (
            % (Language="Русский" ? "Горячая клавиша '" : "The hotkey '") . bareKey . (Language="Русский" ? "' уже используется стратагемой: " : "' is already in use by stratagem: ") . conflictingStratagemName . "."
        )
        return
        }
    }
    
    ; --- II. ПРОВЕРКА И ОБНОВЛЕНИЕ СТРАТАГЕМЫ ---
    if (updateStratagem) {
        newStratagemId := ""
        for id, nameStr in StratagemNames {
            currentName := IsObject(nameStr) ? nameStr[Language] : nameStr
            if (currentName = newStratagemName) {
                newStratagemId := id
                break
            }
        }
        
        if (newStratagemId = "") {
            MsgBox % (Language = "Русский" ? "Ошибка: ID стратагемы не найден для '" . newStratagemName . "'" : "Error: Stratagem ID not found for '" . newStratagemName . "'")
            return
        }
        if (InStr(newStratagemId, "category_") = 1 or InStr(newStratagemId, "separator_") = 1) {
            MsgBox % (Language="Русский" ? "Ошибка: Нельзя привязать категории или разделители." : "Error: Cannot bind categories or separators.")
            return
        }
        finalNewStratID := newStratagemId
    }
    
    ; --- III. ПРОВЕРКА КОНФЛИКТА СТРАТАГЕМЫ ---
    if (updateStratagem) {
        ; Ищем, есть ли уже привязка, использующая НОВУЮ стратагему
        for existingHotkey, existingStratID in Bindings {
            ; Если другая клавиша уже привязана к НОВОЙ стратагеме 
            ; И это не наш текущий старый хоткей (потому что мы его обновляем)
            if (existingStratID = finalNewStratID && existingHotkey != oldBindKey) { 
                
                ; Выдача ошибки и прерывание операции
                MsgBox, 16, % (Language="Русский" ? "Ошибка привязки" : "Binding Error"), % (Language="Русский" ? "Стратагема '" : "The stratagem '") . newStratagemName . (Language="Русский" ? "' уже привязана к клавише '" : "' is already bound to hotkey '") . existingHotkey . "'"
                return
            }
        }
    }

    ; --- IV. УДАЛЕНИЕ СТАРОЙ ЗАПИСИ И ХОТКЕЯ (если клавиша изменилась) ---
    if (finalNewBindKey != oldBindKey) {
        ; 1. Отключение старого хоткея
        Hotkey, %oldBindKey%, StratagemHandler, Off
        
        ; 2. Удаление из Bindings
        Bindings.Delete(oldBindKey)
        
        ; 3. Удаление старой записи KeyMap
        KeyMap.Delete(visibleKey)
    } 
    
    ; --- V. ДОБАВЛЕНИЕ НОВОЙ ПРИВЯЗКИ ---
    
    ; 1. Добавление/Обновление Bindings
    Bindings[finalNewBindKey] := finalNewStratID
    
    ; 2. Обновление KeyMap
    newVisibleKey := RegExReplace(finalNewBindKey, "^\*") ; Получаем ключ без *
    KeyMap[newVisibleKey] := finalNewBindKey
    
    ; 3. Активация нового хоткея
    Hotkey, %finalNewBindKey%, StratagemHandler, On
    
    ; --- VI. СОХРАНЕНИЕ И ОБНОВЛЕНИЕ ---
    SaveBindings()
    ReloadBindingsList()
    UpdateFloatingList()
Return

; --- ReloadBindingsList ---
ReloadBindingsList() {
    global Bindings, StratagemNames, Language, OrderedStratagems, KeyMap
    GuiControl, -Redraw, BindingsList
    LV_Delete()
    KeyMap := Object()

    ; 1. Обратная карта: StratagemID => Массив_Клавиш
    StratagemToHotkeysMap := Object()
    for hotkey, stratID in Bindings {
        if (!StratagemToHotkeysMap.HasKey(stratID)) {
            StratagemToHotkeysMap[stratID] := []
        }
        StratagemToHotkeysMap[stratID].Push(hotkey)
        KeyUpper := Format("{:U}", hotkey)
        KeyMap[KeyUpper] := hotkey
    }

    ; 2. Определим, какие стратагемы имеют привязки
    BoundStratagemIDs := Object()
    for hotkey, stratID in Bindings {
        BoundStratagemIDs[stratID] := true
    }

    ; Убедимся, что 3-й столбец (скрытый ID) имеет ширину 0 (скрыт)
    LV_ModifyCol(3, "0") 

    currentCategory := "" 
    for index, stratID_or_Category in OrderedStratagems {
        isCategory := InStr(stratID_or_Category, "category_") = 1
        ; isActualStratagem := !isCategory && InStr(stratID_or_Category, "separator_") = 0 ; Separators are now ignored entirely

        if (isCategory) {
            foundBoundStratagemInCategory := false
            ; Начинаем сканирование со следующего элемента после текущей категории
            Loop, % OrderedStratagems.Length() {
                scanIndex := A_Index
                if (scanIndex <= index) ; Пропускаем элементы до текущей категории включительно
                    continue

                scanStratID := OrderedStratagems[scanIndex]
                
                ; Если встретили следующую категорию, то эта категория закончилась
                if (InStr(scanStratID, "category_") = 1) {
                    break 
                }
                
                ; Если это не разделитель и стратагема имеет привязку
                if (!InStr(scanStratID, "separator_") && BoundStratagemIDs.HasKey(scanStratID)) {
                    foundBoundStratagemInCategory := true
                    break ; Нашли привязанную стратагему, дальше искать не нужно
                }
            }

            if (foundBoundStratagemInCategory) {
                LV_Add("NoSort", "", StratagemNames[stratID_or_Category][Language], "CAT_" . stratID_or_Category) 
            }
        }
        else if (!InStr(stratID_or_Category, "separator_")) { ; Если это не категория и не разделитель (т.е. actual stratagem)
            if (StratagemToHotkeysMap.HasKey(stratID_or_Category)) {
                hotkeysForThisStratagem := StratagemToHotkeysMap[stratID_or_Category]
                stratName := StratagemNames.HasKey(stratID_or_Category) ? StratagemNames[stratID_or_Category][Language] : (Language = "Русский" ? "(Неизвестная стратагема)" : "(Unknown Stratagem)")

                for _, hotkeyFromMap in hotkeysForThisStratagem {
                    displayedHotkey := Format("{:U}", hotkeyFromMap)
                    LV_Add("", displayedHotkey, stratName, stratID_or_Category)
                }
            }
        }
    }
    GuiControl, +Redraw, BindingsList
	
	; Сбрасываем выпадающие списки, поле ввода UserHotkey, WildCard, KeyPreview после обновления таблицы
    GuiControl, Choose, UserHotkeyDDL, 1
	GuiControl, Choose, SelectedStratagem, 0
	GuiControl,, UserHotkey,
	GuiControl,, KeyPreviewText,
	GuiControl, , UserHotkeyWildcard, 0
}

SaveBindings() {
    global Bindings, IniFile, ActiveProfile, SuspendHotkey, ExitHotkey
    
    section := "Binds_" . ActiveProfile
    
    ; Удаляем всю секцию, чтобы начать с чистого листа
    IniDelete, %IniFile%, %section%
    
    ; Загружаем глобальные привязки для сравнения
    globalBindings := Object()
    globalSection := "Binds_Global-Stratagems"
    IniRead, globalKeysList, %IniFile%, %globalSection%
    if (globalKeysList != "ERROR") {
        Loop, Parse, globalKeysList, `n, `r
        {
            StringSplit, Pair, A_LoopField, =
            key := Trim(Pair1)
            strat := Trim(Pair2)
            if (key != "" && strat != "")
                globalBindings[key] := strat
        }
    }
    
    ; Инициализируем счетчик записанных привязок
    bindingsWritten := 0
    
    ; Сохраняем только те привязки, которые не существуют в глобальном профиле
    for key, strat in Bindings {
        if (!globalBindings.HasKey(key) || globalBindings[key] != strat) {
            IniWrite, %strat%, %IniFile%, %section%, %key%
            bindingsWritten++ ; Увеличиваем счетчик
        }
    }
    
    ; Если ни одна привязка не была записана, добавляем служебный ключ
    if (bindingsWritten = 0) {
        IniWrite, Empty, %IniFile%, %section%, Status
    }
    
    ; Сохраняем другие настройки
    IniWrite, %ActiveProfile%, %IniFile%, Config, ActiveProfile
    IniWrite, %SuspendHotkey%, %IniFile%, Config, SuspendHotkey
    IniWrite, %ExitHotkey%, %IniFile%, Config, ExitHotkey
}

LoadBindings() {
    global Bindings, IniFile, ActiveProfile, DefaultProfile, SuspendHotkey, ExitHotkey
    
    ; Загружаем глобальные настройки
    IniRead, ActiveProfile, %IniFile%, Config, ActiveProfile, %DefaultProfile%
    IniRead, SuspendHotkey, %IniFile%, Config, SuspendHotkey, Insert
    IniRead, ExitHotkey, %IniFile%, Config, ExitHotkey, End
    
    Bindings := Object()
    KeyMap := Object()
    if !FileExist(IniFile)
        return
    
    ; === Шаг 1: Загружаем все привязки в объект Bindings ===
    ; Сначала из глобального профиля
    globalSection := "Binds_Global-Stratagems"
    IniRead, globalKeysList, %IniFile%, %globalSection%
    if (globalKeysList != "ERROR") {
        Loop, Parse, globalKeysList, `n, `r
        {
            if A_LoopField =
                continue
            StringSplit, Pair, A_LoopField, =
            key := Trim(Pair1)
            strat := Trim(Pair2)
            
            ; Игнорируем служебную строку "Status=Empty"
            if (key = "Status") {
                continue
            }
            
            if (key != "" && strat != "") {
                Bindings[key] := strat
            }
        }
    }
    
    ; Затем из активного профиля (перезаписывая глобальные)
    section := "Binds_" . ActiveProfile
    IniRead, keysList, %IniFile%, %section%
    if (keysList != "ERROR") {
        Loop, Parse, keysList, `n, `r
        {
            if A_LoopField =
                continue
            StringSplit, Pair, A_LoopField, =
            key := Trim(Pair1)
            strat := Trim(Pair2)
            
            ; Игнорируем служебную строку "Status=Empty"
            if (key = "Status") {
                continue
            }
            
            if (key != "" && strat != "") {
                Bindings[key] := strat
            }
        }
    }
    
    ; === Шаг 2: Активируем горячие клавиши из объекта Bindings ===
    ; Этот цикл гарантирует, что мы активируем ТОЛЬКО корректные привязки
    for key, strat in Bindings {
        Hotkey, %key%, StratagemHandler, On
        
        ; Также заполняем KeyMap здесь, чтобы он был актуален
        KeyUpper := Format("{:U}", key)
        KeyMap[KeyUpper] := key
    }
}

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
    
    ; 1. Собираем ВСЕ найденные профили
    allProfiles := {} 
    Loop, Read, %IniFile%
    {
        if RegExMatch(A_LoopReadLine, "^\[Binds_(.+)\]$", m)
            allProfiles[m1] := true
    }
    
    ; Убедимся, что профили по умолчанию существуют
    allProfiles["Global-Stratagems"] := true
    allProfiles["Default"] := true

    
    ; 2. Разделяем профили на фиксированные и пользовательские
    fixedProfiles := ["Global-Stratagems", "Default"]
    userProfiles := []
    
    for profileName in allProfiles {
        ; Если имя профиля НЕ содержится в фиксированном списке, добавляем его к пользовательским
        if (profileName != "Global-Stratagems" && profileName != "Default") {
            userProfiles.Push(profileName)
        }
    }
    
    ; 3. Сортируем пользовательские профили
    userProfiles.Sort() 

    ; 4. Строим финальный список (Фиксированные + Разделитель + Отсортированные)
    list := ""
    
    ; Добавляем фиксированные
    for _, name in fixedProfiles
        list .= name . "|"
        
    ; Добавляем разделитель
    list .= " |"
        
    ; Добавляем отсортированные пользовательские
    for _, name in userProfiles
        list .= name . "|"
    
    return RTrim(list, "|")
}

; === Функция для отключения всех активных привязок ===
DeactivateAllBindings() {
    global Bindings
    ; Перебираем все горячие клавиши в текущем объекте Bindings
    for key, _ in Bindings {
        if (key != "") { ; На всякий случай, если ключ пуст
            Hotkey, %key%, Off ; Отключаем горячую клавишу
        }
    }
    ; Полностью очищаем объект Bindings, чтобы не осталось старых данных
    Bindings := Object()
}

SwitchProfileFromDDL:
    Gui, Submit, NoHide ; обновляет автоматически связанную переменную ActiveProfileDDL
	; Проверка на пустой разделитель
    if (ActiveProfileDDL = " ") {
        GuiControl, ChooseString, ActiveProfileDDL, %ActiveProfile%
        return
    }
    GoSub, SwitchProfile ; Вызываем основную метку SwitchProfile:
Return

SwitchProfile:
global ActiveProfileDDL, ActiveProfile
if (ActiveProfileDDL = " " || ActiveProfileDDL = "") {
    GuiControl, ChooseString, ActiveProfileDDL, %ActiveProfile%
    return
}
DeactivateAllBindings()
ActiveProfile := ActiveProfileDDL ; Убедитесь, что ActiveProfile действительно обновляется
IniWrite, %ActiveProfile%, %IniFile%, Config, ActiveProfile
IniRead, Dummy, %IniFile%, Binds_%ActiveProfile%
if (Dummy = "ERROR")
    IniWrite, Empty, %IniFile%, Binds_%ActiveProfile%, Status
LoadBindings()
ReloadBindingsList()
GuiControl,, ActiveProfileDDL, |
GuiControl,, ActiveProfileDDL, % GetProfilesList()
GuiControl, ChooseString, ActiveProfileDDL, %ActiveProfile%
    ToolTipText := (Language = "Русский" ? "Активный профиль: " : "Active Profile: ") . ActiveProfile
    ToolTip, %ToolTipText%, A_ScreenWidth - 200, A_ScreenHeight - 50
    SetTimer, RemoveToolTip, -1000
; Обновляем плавающее окно
UpdateFloatingWindow()
return 

CreateProfile:
    DeactivateAllBindings()
    InputBox, NewProfileName, % (Language = "Русский" ? "Новый профиль" : "New Profile"), % (Language = "Русский" ? "Введите имя нового профиля:" : "Enter a name for the new profile:")
    if (NewProfileName = ""){
        LoadBindings()
        return
    }

    IniWrite, Empty, %IniFile%, Binds_%NewProfileName%, Status
    
    ActiveProfile := NewProfileName
    IniWrite, %ActiveProfile%, %IniFile%, Config, ActiveProfile
    LoadProfiles()
    GuiControl,, ActiveProfileDDL, |
    GuiControl,, ActiveProfileDDL, % GetProfilesList()
    GuiControl, ChooseString, ActiveProfileDDL, %ActiveProfile%
    LoadBindings()
    ReloadBindingsList()
    MsgBox % (Language = "Русский" ? "Создан новый профиль: " : "New profile created: ") . ActiveProfile
    UpdateFloatingWindow()
return

DeleteProfile:
	if (ActiveProfile = "Default" || ActiveProfile = "Global-Stratagems") {
			MsgBox % (Language = "Русский" ? "Нельзя удалить этот профиль!" : "Cannot delete this profile!")
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
	MsgBox % (Language = "Русский" ? "Профиль удален. Активен профиль: " : "Profile deleted. Active profile: ") . ActiveProfile
	UpdateFloatingWindow()
return

; === Exit Script ===
SetExitHotkey()
{
    global ExitHotkey
    ; Используем статическую переменную, чтобы помнить последнюю успешно установленную горячую клавишу Exit
    static CurrentActiveExitHotkey := ""

    ; Чтобы ExitHotkey срабатывал независимо от модификаторов (Ctrl, Alt, Shift, Win), используем префикс "*".
    HotkeyToActivate := ExitHotkey
    ; Checking if it's not empty AND the first character is not "*"
    if (HotkeyToActivate != "" && SubStr(HotkeyToActivate, 1, 1) != "*")
    {
        HotkeyToActivate := "*" . HotkeyToActivate
    }

    ; --- Отключаем предыдущую горячую клавишу, если она была активна и валидна ---
    ; Проверяем, что CurrentActiveExitHotkey не пуста и не содержит "ERROR" или пробелы.
    if (CurrentActiveExitHotkey != "" && RegExMatch(CurrentActiveExitHotkey, "^\S+$"))
    {
        Hotkey, %CurrentActiveExitHotkey%, ExitAppFunc, Off
    }

    ; --- Устанавливаем новую горячую клавишу, если она валидна ---
    ; Проверяем, что новая клавиша не пуста и не содержит "ERROR" или пробелы.
    if (HotkeyToActivate != "" && RegExMatch(HotkeyToActivate, "^\S+$"))
    {
        Hotkey, %HotkeyToActivate%, ExitAppFunc, On
        CurrentActiveExitHotkey := HotkeyToActivate ; Запоминаем эту горячую клавишу как активную
    }
    else ; Если новая горячая клавиша пуста или невалидна, просто убедимся, что никакая клавиша не отслеживается как активная для Exit.
    {
        CurrentActiveExitHotkey := ""
    }
}

ExitAppFunc:
    Suspend, Permit
	ExitApp
Return

; === Suspend/Toggle Script ===
SetSuspendHotkey()
{
    global SuspendHotkey
    ; Используем статическую переменную, чтобы помнить последнюю успешно установленную горячую клавишу Suspend
    static CurrentActiveSuspendHotkey := ""

    ; Чтобы SuspendHotkey срабатывал независимо от модификаторов (Ctrl, Alt, Shift, Win), используем префикс "*".
    HotkeyToActivate := SuspendHotkey
    ; Checking if it's not empty AND the first character is not "*"
    if (HotkeyToActivate != "" && SubStr(HotkeyToActivate, 1, 1) != "*")
    {
        HotkeyToActivate := "*" . HotkeyToActivate
    }

    ; --- Отключаем предыдущую горячую клавишу, если она была активна и валидна ---
    ; Проверяем, что CurrentActiveSuspendHotkey не пуста и не содержит "ERROR" или пробелы.
    if (CurrentActiveSuspendHotkey != "" && RegExMatch(CurrentActiveSuspendHotkey, "^\S+$"))
    {
        Hotkey, %CurrentActiveSuspendHotkey%, SuspendToggle, Off
    }

    ; --- Устанавливаем новую горячую клавишу, если она валидна ---
    ; Проверяем, что новая клавиша не пуста и не содержит "ERROR" или пробелы.
    if (HotkeyToActivate != "" && RegExMatch(HotkeyToActivate, "^\S+$"))
    {
        Hotkey, %HotkeyToActivate%, SuspendToggle, On
        CurrentActiveSuspendHotkey := HotkeyToActivate ; Запоминаем эту горячую клавишу как активную
    }
    else ; Если новая горячая клавиша пуста или невалидна, просто убедимся, что никакая клавиша не отслеживается как активная для Suspend.
    {
        CurrentActiveSuspendHotkey := ""
    }
}

AutoPauseCheckbox() {
    global AutoPauseActive 
    
    ; Выполняем проверку. Если галочка стоит (1), вызываем метку
    if (AutoPauseActive = 1) {
        GoSub, ToggleAutoPause
    }
    return
}

ToggleAutoPause:
    global AutoPauseActive, ScriptSuspended, AutoPauseTimerInterval
	; Получаем текущее состояние галочки (1 или 0)
    GuiControlGet, AutoPauseActive, , AutoPauseActive 
	IniWrite, %AutoPauseActive%, %IniFile%, Config, AutoPauseActive
    

    if (AutoPauseActive)
    {
        ; Галочка включена: ЗАПУСКАЕМ таймер для мониторинга
        SetTimer, AutoPauseCheck, %AutoPauseTimerInterval%
        ToolTip, % (Language="Русский" ? "Автопауза ВКЛ" : "AutoPause ON"), A_ScreenWidth - 200, A_ScreenHeight - 50
    }
    else
    {
        ; Галочка выключена: ОСТАНАВЛИВАЕМ таймер
        SetTimer, AutoPauseCheck, Off
        
        ; Если скрипт был принудительно приостановлен автопаузой, восстанавливаем состояние пользователя
        if (A_IsSuspended)
        {
            global ScriptSuspended
            ; Восстанавливаем состояние, которое выбрал пользователь
            Suspend, % (ScriptSuspended ? "On" : "Off") 
        }
		UpdateToggleButtonText()
        ToolTip, % (Language="Русский" ? "Автопауза ВЫКЛ" : "AutoPause OFF"), A_ScreenWidth - 200, A_ScreenHeight - 50
    }
    SetTimer, RemoveToolTip, -1000
    return


; === ФУНКЦИЯ АВТОПАУЗЫ (Вызывается только таймером) ===
AutoPauseCheck:
    global ScriptSuspended

    IfWinActive, %GameTarget%
    {
        ;  A. РЕЖИМ "ВНУТРИ ИГРЫ"
        ; Восстанавливаем состояние, которое выбрал пользователь (ON/OFF)
        if (A_IsSuspended != ScriptSuspended) {
            Suspend, % (ScriptSuspended ? "On" : "Off")
            UpdateToggleButtonText()
			ToolTip, % (Language="Русский" ? "Автопауза Снята" : "AutoPause Removed"), A_ScreenWidth - 200, A_ScreenHeight - 50
			SetTimer, RemoveToolTip, -1000
        }
    }
    Else
    {
        ;  B. РЕЖИМ "ВНЕ ИГРЫ" (Принудительная пауза)
        ; Если скрипт не на паузе (т.е. A_IsSuspended=False)
        if (!A_IsSuspended) 
        {
            Suspend, On
            ; Устанавливаем статус PAUSED для GUI
            UpdateToggleButtonText("PAUSED") 
			ToolTip, % (Language="Русский" ? "Автопауза Активна" : "AutoPause Active"), A_ScreenWidth - 200, A_ScreenHeight - 50
			SetTimer, RemoveToolTip, -1000
        }
    }
return

SuspendToggle: ; Hotkey label for script suspension
Suspend
global ScriptSuspended ; Update global variable based on actual suspend state
ScriptSuspended := A_IsSuspended
ToolTip,% A_IsSuspended ? (Language="Русский" ? "Скрипт выкл" : "Script is off") : (Language="Русский" ? "Скрипт вкл" : "Script is on"), A_ScreenWidth - 200, A_ScreenHeight - 50
UpdateToggleButtonText() ; Update main toggle button
SetTimer, RemoveToolTip, -1000
return

ToggleScriptButton: ; G-label for the main toggle button
    Suspend
    global ScriptSuspended
    ScriptSuspended := A_IsSuspended
    UpdateToggleButtonText() ; Update the button text
    ToolTip,% A_IsSuspended ? (Language="Русский" ? "Скрипт выкл" : "Script is off") : (Language="Русский" ? "Скрипт вкл" : "Script is on"), A_ScreenWidth - 200, A_ScreenHeight - 50
    SetTimer, RemoveToolTip, -1000
Return

UpdateToggleButtonText(status="") {
    global Language, ScriptSuspended, GameTarget, AutoPauseActive
    
    ; 1. Проверка: Был ли статус "PAUSED" принудительно установлен
    if (status = "PAUSED")
    {
        buttonText := (Language="Русский" ? "ПАУЗА" : "PAUSED")
        indicatorColor := "Yellow"
    } 
    ; 2. Проверка: Скрипт в данный момент приостановлен (A_IsSuspended = True)
    else if (A_IsSuspended) 
    {
        ; Определяем, активна ли АВТО-ПАУЗА (Желтый индикатор)
        ; а) Функция AutoPause включена (AutoPauseActive = 1) 
        ; б) Игровое окно НЕ активно (!WinActive(GameTarget))
        if (AutoPauseActive AND !WinActive(GameTarget))
        {
            buttonText := (Language="Русский" ? "ПАУЗА" : "PAUSED")
            indicatorColor := "Yellow"
        }
        ; Иначе, причина приостановки — РУЧНАЯ пауза (Красный индикатор)
        else {
            buttonText := (Language="Русский" ? "ВКЛ" : "ON") ; Текст кнопки для включения
            indicatorColor := "Red"
        }
    }
    ; 3. Иначе: Скрипт НЕ приостановлен (Зеленый индикатор - Ручной ON)
    else {
        buttonText := (Language="Русский" ? "ВЫКЛ" : "OFF") ; Текст кнопки для выключения
        indicatorColor := "Green"
    }

    GuiControl,, ToggleScriptBtn, %buttonText%
    GuiControl, +c%indicatorColor%, ScriptStatusIndicator 
    GuiControl,, ScriptStatusIndicator, % (ScriptSuspended ? 100 : 100)
    return
}

UpdateFloatingHotkey:
    Gui, Submit, NoHide
    Hotkey, %FloatingWindowHotkey%, ToggleFloatingWindow, Off ; выключить старую привязку
    FloatingWindowHotkey := FloatingHotkeyControl
    SetFloatingWindowHotkey()
Return

SetFloatingWindowHotkey(newHotkey := "") {
    global FloatingWindowHotkey
    static CurrentActiveFloatingHotkey := ""

    ; Отключаем предыдущую, если есть
    if (CurrentActiveFloatingHotkey != "") {
        Hotkey, %CurrentActiveFloatingHotkey%, ToggleFloatingWindow, Off
    }

    ; Если указан новый хоткей (из GUI), обновляем переменную
    if (newHotkey != "") {
        FloatingWindowHotkey := Trim(newHotkey)
    }

    ; Включаем новую горячую клавишу
    if (FloatingWindowHotkey != "") {
        Hotkey, %FloatingWindowHotkey%, ToggleFloatingWindow, On
        CurrentActiveFloatingHotkey := FloatingWindowHotkey
    } else {
        CurrentActiveFloatingHotkey := "" ; очищаем трекер, если пусто
    }
}

ToggleFloatingWindowButton:
    ToggleFloatingWindow() ; Вызываем функцию переключения видимости
Return

ToggleFloatingWindow()
{
    global FloatingGuiVisible
	global Language

    if (!FloatingGuiVisible) {
        LoadFloatingGuiPosition() ; загружаем позицию перед показом
        UpdateFloatingList()
        Gui, FloatingGui:Show, NA x%FloatingGuiX% y%FloatingGuiY%, FloatingBindings
        FloatingGuiVisible := true
    } else {
        SaveFloatingGuiPosition() ; сохраняем позицию перед скрытием
        Gui, FloatingGui:Hide
        FloatingGuiVisible := false
    }
	Gui, 1:Default 
	GuiControl,, ToggleFloatingWindowBtn, % (Language = "Русский" ? (FloatingGuiVisible ? "Спрятать" : "Показать") : (FloatingGuiVisible ? "Hide" : "Show"))
    return
}

UpdateFloatingList() {
    global Bindings, StratagemNames, Language, FloatingGuiVisible, ActiveProfile
    global FloatingGuiCreated, FloatingGuiX, FloatingGuiY, FloatingGuiOpacity
    global OrderedStratagems, KeyMap, HiddenCategories 

    if (FloatingGuiCreated) {
        Gui, FloatingGui:Destroy
        FloatingGuiCreated := false
    }

    Gui, FloatingGui:New
    Gui, +AlwaysOnTop -Caption +ToolWindow +LastFound
    WinSet, Transparent, %FloatingGuiOpacity%
    Gui, Margin, 10, 10
    Gui, Color, 000000
    Gui, Font, s10 cWhite

    Gui, Add, Text, x0 y0 w300 h20 gStartMove BackgroundTrans Border Center, % (Language = "Русский" ? "Профиль: " : "Profile: ") . ActiveProfile

    y := 30 
    
    BoundStratagemIDs := Object()
    for hotkey, stratID in Bindings {
        BoundStratagemIDs[stratID] := true
    }

    if (!Bindings || ObjCount(Bindings) = 0) {
        emptyMsg := (Language = "Русский" ? "Список привязок пуст." : "Binding list is empty.")
        Gui, Add, Text, x10 y%y% BackgroundTrans cWhite, %emptyMsg%
    } else {
        currentCategoryIsHiddenBySetting := false 

        for index, stratID in OrderedStratagems {
            isCategory := InStr(stratID, "category_") = 1
            isSeparator := InStr(stratID, "separator_") = 1

            if (isCategory) {
                if (HiddenCategories.HasKey(stratID) && HiddenCategories[stratID] = true) {
                    currentCategoryIsHiddenBySetting := true
                    continue 
                } else {
                    currentCategoryIsHiddenBySetting := false 
                }

                foundBoundStratagemInCategory := false
                Loop, % OrderedStratagems.Length() {
                    localScanIndex := A_Index
                    if (localScanIndex <= index)
                        continue

                    scanStratID := OrderedStratagems[localScanIndex]
                    
                    if (InStr(scanStratID, "category_") = 1) {
                        break 
                    }
                    
                    if (!InStr(scanStratID, "category_") && !InStr(scanStratID, "separator_") && BoundStratagemIDs.HasKey(scanStratID)) {
                        foundBoundStratagemInCategory := true
                        break 
                    }
                }

                if (foundBoundStratagemInCategory) {
                    ; --- Проверка на скрытие названия категории ---
                    if (!(HiddenCategories.HasKey("hide_category_names") && HiddenCategories["hide_category_names"] = true)) {
                        Gui, Add, Text, x10 y%y% w280 BackgroundTrans cWhite Center, % StratagemNames[stratID][Language]
                        y += 20 
                    }
                }
            } 
            else if (isSeparator) {
				separatorNumber := 0
                RegExMatch(stratID, "\d+$", separatorNumber)
                if (separatorNumber >= 4 || stratID = "separator_") {
                    continue ; Пропускаем этот разделитель полностью
                }
                if (HiddenCategories.HasKey("separator_") && HiddenCategories["separator_"] = true) {
                    continue 
                }

                hasVisibleContentAfterSeparator := false
                Loop, % OrderedStratagems.Length() {
                    localScanIndex := A_Index
                    if (localScanIndex <= index)
                        continue

                    nextID := OrderedStratagems[localScanIndex]
                    nextIsCategory := InStr(nextID, "category_") = 1
                    nextIsSeparator := InStr(nextID, "separator_") = 1

                    if (nextIsCategory) {
                        if (!HiddenCategories.HasKey(nextID) || HiddenCategories[nextID] = false) {
                            nextCategoryHasBoundStratagem := false
                            Loop, % OrderedStratagems.Length() {
                                localScanStratIndex := A_Index
                                if (localScanStratIndex <= localScanIndex)
                                    continue

                                scanStratID := OrderedStratagems[localScanStratIndex]
                                if (InStr(scanStratID, "category_") = 1) {
                                    break 
                                }
                                if (!InStr(scanStratID, "separator_") && BoundStratagemIDs.HasKey(scanStratID)) {
                                    nextCategoryHasBoundStratagem := true
                                    break
                                }
                            }
                            if (nextCategoryHasBoundStratagem) {
                                hasVisibleContentAfterSeparator := true
                                break 
                            }
                        }
                    }
                    else if (!nextIsCategory && !nextIsSeparator) {
                        if (BoundStratagemIDs.HasKey(nextID)) {
                            hasVisibleContentAfterSeparator := true
                            break 
                        }
                    }
                    if (localScanIndex = OrderedStratagems.Length()) {
                        break
                    }
                }

                if (hasVisibleContentAfterSeparator) {
                    Gui, Add, Text, x10 y%y% w280 BackgroundTrans cGrey Center, ---
                    y += 10 
                }
            }
            else {
                if (currentCategoryIsHiddenBySetting) {
                    continue
                }

                foundHotkey := ""
                for hotkey, boundStratID in Bindings {
                    if (boundStratID = stratID) {
                        foundHotkey := hotkey
                        break
                    }
                }

                if (foundHotkey != "") {
                    stratName := ""
                    if (StratagemNames.HasKey(stratID)) {
                        stratName := StratagemNames[stratID][Language]
                    } else {
                        stratName := (Language = "Русский" ? "(Неизвестная стратагема)" : "(Unknown Stratagem)")
                    }
                    
                    displayedHotkey := Format("{:U}", foundHotkey)
                    Gui, Add, Text, x10 y%y% BackgroundTrans cWhite, % displayedHotkey " → " stratName
                    y += 20 
                }
            }
        }
    }
	
	; --- Отображение Ассистентов ---
    if ((WeaponAssistantActive or DriverAssistantActive) and !HiddenCategories["hidden_assistants"]) {
    if (!HiddenCategories["hide_category_names"]) {
        Gui, Add, Text, x10 y%y% w280 BackgroundTrans Center, % (Language = "Русский" ? "--- Ассистент ---" : "--- Assistant ---")
        y += 20
    }
    
    ; Блок для WeaponAssistant
    if (WeaponAssistantActive) {
        modeName := WeaponModeNames[Language = "Русский" ? "ru" : "en"][CurrentWeaponMode]
        assistantText := (Language = "Русский" ? "Ассистент Оружия: " : "Weapon Assistant: ") . modeName
        Gui, Add, Text, x10 y%y% BackgroundTrans cWhite, % assistantText
        y += 20
    }
    
    ; Блок для DriverAssistant
    if (DriverAssistantActive) {
        driverText := (Language = "Русский" ? "Ассистент Вождения: Активен" : "Driver Assistant: Active")
        Gui, Add, Text, x10 y%y% BackgroundTrans cWhite, % driverText
        y += 20
    }
}

    if (FloatingGuiVisible)
        Gui, Show, x%FloatingGuiX% y%FloatingGuiY% NoActivate AutoSize, FloatingBindings

    FloatingGuiCreated := true
}

UpdateOpacity:
    Gui, Submit, NoHide
    FloatingGuiOpacity := FloatingOpacitySlider
    if (FloatingGuiVisible)
        WinSet, Transparent, %FloatingGuiOpacity%, FloatingBindings
	SaveFloatingGuiPosition()
Return

SaveFloatingGuiPosition() {
    global FloatingGuiX, FloatingGuiY, FloatingGuiOpacity
    WinGetPos, x, y, , , FloatingBindings
    if (x != "")
    {
        IniWrite, %x%, %IniFile%, FloatingGui, X
        IniWrite, %y%, %IniFile%, FloatingGui, Y
        FloatingGuiX := x
        FloatingGuiY := y
    }
	IniWrite, %FloatingGuiOpacity%, %IniFile%, FloatingGui, Opacity
}

LoadFloatingGuiPosition() {
    global FloatingGuiX, FloatingGuiY, FloatingGuiOpacity
    IniRead, x, %IniFile%, FloatingGui, X, 100
    IniRead, y, %IniFile%, FloatingGui, Y, 100
    FloatingGuiX := x
    FloatingGuiY := y
	IniRead, opacity, %IniFile%, FloatingGui, Opacity, 128
	FloatingGuiOpacity := opacity
}

StartMove:
    PostMessage, 0xA1, 2,,, A ; WM_NCLBUTTONDOWN + HTCAPTION
return

UpdateFloatingWindow()
{
if (FloatingGuiVisible) {
    SaveFloatingGuiPosition()
	UpdateFloatingList()
}
}

UpdateFloatingListSetting() {
    global FloatingListSettingsFile, HiddenCategories, OrderedStratagems

    CtrlName := A_GuiControl
    CtrlValue := A_GuiControlEvent

    valueToSave := ""

    if (CtrlValue = 1) {
        valueToSave := "1"
    } else if (CtrlValue = 0) {
        valueToSave := "0"
    } else {
        if (CtrlName = "HiddenSeparator") {
            valueToSave := HiddenCategories["separator_"] ? "0" : "1"
        } 
        ; --- Обработка чекбокса названия категорий ---
        else if (CtrlName = "HideCategoryNames") {
            valueToSave := HiddenCategories["hide_category_names"] ? "0" : "1"
        }
		; --- Обработка чекбокса ассистентов ---
		else if (CtrlName = "Hidden_Assistants") {
            valueToSave := HiddenCategories["hidden_assistants"] ? "0" : "1"
        }
        else if (InStr(CtrlName, "Hidden_category_") = 1) {
            categoryID := SubStr(CtrlName, 8)
            valueToSave := HiddenCategories[categoryID] ? "0" : "1"
        }
    }

    ; Обновляем глобальную переменную HiddenCategories и сохраняем в INI
    if (CtrlName = "HiddenSeparator") {
        HiddenCategories["separator_"] := (valueToSave = "1" ? true : false)
        IniWrite, %valueToSave%, %IniFile%, FloatingGui, separator_
    } 
    ; --- Сохраняем переменную HideCategoryNames ---
    else if (CtrlName = "HideCategoryNames") {
        HiddenCategories["hide_category_names"] := (valueToSave = "1" ? true : false)
        IniWrite, %valueToSave%, %IniFile%, FloatingGui, hide_category_names
    }
	; --- Сохраняем состояния ассистентов ---
    else if (CtrlName = "Hidden_Assistants") {
        HiddenCategories["hidden_assistants"] := (valueToSave = "1" ? true : false)
        IniWrite, %valueToSave%, %IniFile%, FloatingGui, hidden_assistants
    }
    else if (InStr(CtrlName, "Hidden_category_") = 1) {
        categoryID := SubStr(CtrlName, 8)
        HiddenCategories[categoryID] := (valueToSave = "1" ? true : false)
        IniWrite, %valueToSave%, %IniFile%, FloatingGui, %categoryID%
    }
    
    UpdateFloatingWindow()
}

; --- FloatingList Visibility Settings ---
LoadFloatingListSettings() {
    global IniFile, HiddenCategories, OrderedStratagems, StratagemNames, Language

    HiddenCategories := Object() 
    
    for index, id in OrderedStratagems {
        if (InStr(id, "category_") = 1) {
            HiddenCategories[id] := false
        }
    }

    ; --- Загрузка для разделителей и названий категорий ---
    IniRead, value, %IniFile%, FloatingGui, separator_, 1
    if (value != "") {
        HiddenCategories["separator_"] := (value = "1" ? true : false)
    }
    IniRead, value, %IniFile%, FloatingGui, hide_category_names
    if (value != "") {
        HiddenCategories["hide_category_names"] := (value = "1" ? true : false)
    }
	 ; --- Загрузка состояния ассистентов ---
    IniRead, value, %IniFile%, FloatingGui, hidden_assistants
    if (value != "") {
        HiddenCategories["hidden_assistants"] := (value = "1" ? true : false)
    }

    ; --- Загрузка для каждой категории ---
    ; Итерируем по OrderedStratagems, чтобы найти все Category IDs
    for index, categoryID_or_other_id in OrderedStratagems {
        ; Убеждаемся, что текущий элемент является категорией
        if (InStr(categoryID_or_other_id, "category_") = 1) {
            categoryID := categoryID_or_other_id ; Присваиваем для удобства
            IniRead, value, %IniFile%, FloatingGui, %categoryID%
            if (value != "") {
                HiddenCategories[categoryID] := (value = "1" ? true : false)
            }
        }
    }

    ; --- Обновляем состояние чекбоксов в GUI ---
    ; Обновляем чекбокс для разделителей
    GuiControl, , HiddenSeparator, % HiddenCategories["separator_"] ? 1 : 0
	; Обновление чекбокса названия категорий
    GuiControl, , HideCategoryNames, % HiddenCategories["hide_category_names"] ? 1 : 0
	; Обновление чекбокса ассистента
    GuiControl, , Hidden_Assistants, % HiddenCategories["hidden_assistants"] ? 1 : 0

    ; Обновляем чекбоксы для каждой категории
    for index, categoryID_or_other_id in OrderedStratagems {
        if (InStr(categoryID_or_other_id, "category_") = 1) {
            categoryID := categoryID_or_other_id
            checkboxName := "Hidden_" . categoryID ; Формируем имя контрола, например "Hidden_category_defensive_stratagems"
            
            ; Проверяем, существует ли контрол с таким именем, прежде чем пытаться его обновить.
            GuiControlGet, output, Hwnd, %checkboxName%
            if (output) { ; Если контрол найден (output содержит его Hwnd)
                GuiControl, , %checkboxName%, % HiddenCategories[categoryID] ? 1 : 0
            }
        }
    }
}

; --- Weapon Assistant Handlers ---
WPModeChanged:
    Gui, Submit, NoHide
    Loop, 4
        if (WPSelectedMode = WeaponModeNames[Language = "Русский" ? "ru" : "en"][A_Index])
            CurrentWeaponMode := A_Index
    UpdateWeaponStatus()
Return

; --- Функция для обновления и валидации процента ---
UpdateAndValidateChargePercent() {
    global UnsafeChargePercent, WPChargePercentInput

    if (WPChargePercentInput = "")
        return ; Ничего не делаем, если поле пустое

    val := WPChargePercentInput + 0 
    if (val < 16)
        val := 16
    else if (val > 100)
        val := 100
    
    UnsafeChargePercent := val ; Обновляем глобальную переменную
    GuiControl,, WPChargePercentInput, %UnsafeChargePercent% ; Обновляем GUI
}

WPUnsafeChargeChanged:
    Gui, Submit, NoHide
    UpdateAndValidateChargePercent()
    SaveWeaponSettings()
Return

ToggleWeaponFunc:
    WeaponAssistantActive := !WeaponAssistantActive
    UpdateWeaponStatus()
Return

CycleWeaponModeFunc:
    CurrentWeaponMode := (CurrentWeaponMode = 4) ? 1 : CurrentWeaponMode + 1
    GuiControl, Choose, WPSelectedMode, % WeaponModeNames[Language = "Русский" ? "ru" : "en"][CurrentWeaponMode]
    UpdateWeaponStatus()
Return

UpdateWeaponStatus()
{
    local modeDisplayName
    modeDisplayName := WeaponModeNames[Language = "Русский" ? "ru" : "en"][CurrentWeaponMode]
    if (WeaponAssistantActive) {
        ToolTip % (Language="Русский" ? "Ассистент Оружия Активен: " : "Weapon Assistant Active: ") . modeDisplayName, A_ScreenWidth - 200, A_ScreenHeight - 50
        GuiControl,, WPStatusText, % (Language="Русский" ? "Активен[" : "Active[") . modeDisplayName . "]"
        
        ; Включаем hotkey для предохранителя, если он задан.
        if (SafetyHotkey != "") {
            Hotkey, %SafetyHotkey%, WPSafetyHotkeyFunc, On
        } else {
            ; Если предохранитель не задан, напрямую включаем LButtonMacro.
            if (WeaponAssistHotkey != "") {
                Hotkey, %WeaponAssistHotkey%, LButtonMacro, On
            }
        }
    } else {
        ToolTip % (Language="Русский" ? "Ассистент Оружия: Выключен" : "Weapon Assistant: Disabled"), A_ScreenWidth - 200, A_ScreenHeight - 50
        GuiControl,, WPStatusText, % (Language="Русский" ? "Выключен." : "Disabled.")
        
        ; При деактивации ассистента всегда выключаем все связанные хоткеи.
        if (SafetyHotkey != "") {
            Hotkey, %SafetyHotkey%, WPSafetyHotkeyFunc, Off
        }
        if (WeaponAssistHotkey != "") {
            Hotkey, %WeaponAssistHotkey%, LButtonMacro, Off
        }
    }
    UpdateFloatingWindow()
    SetTimer, RemoveTooltip, -1000
}

ToggleDriverFunc:
    DriverAssistantActive := !DriverAssistantActive
    UpdateDriverStatus()
Return

UpdateDriverStatus()
{
    If DriverAssistantActive {
        ToolTip % (Language="Русский" ? "Ассистент Вождения: Активен" : "Driver Assistant: Active"), A_ScreenWidth - 200, A_ScreenHeight - 50
		GuiControl,, DAStatusText, % (Language="Русский" ? "Активен" : "Active")
        ; Activate the W,S and E hotkeys only when the assistant is active
        If (!ScriptSuspended) {
            Hotkey, *~w, DriverMacroW, On
            Hotkey, *~s, DriverMacroS, On
			Hotkey, *~e, DriverMacroE, On
        }
    } else {
        ToolTip % (Language="Русский" ? "Ассистент Вождения: Выключен" : "Driver Assistant: Disabled"), A_ScreenWidth - 200, A_ScreenHeight - 50
        GuiControl,, DAStatusText, % (Language="Русский" ? "Выключен." : "Disabled.")
        ; Deactivate the W,S and E hotkeys when the assistant is not active
        Hotkey, *~w, DriverMacroW, Off
        Hotkey, *~s, DriverMacroS, Off
		Hotkey, *~e, DriverMacroE, Off
		LastKey := ""
    }
	UpdateFloatingWindow()
    SetTimer, RemoveTooltip, -1000
}

InitWeaponGUIControls()
{
    global WeaponModeNames, Language, CurrentWeaponMode, ToggleWeaponHotkey, CycleWeaponModeHotkey, DriverAssistHotkey, UnsafeChargePercent
    
    ; Clear the existing list before adding new items
    GuiControl,, WPSelectedMode, |

    ModeListString := WeaponModeNames[Language = "Русский" ? "ru" : "en"][1] "|" WeaponModeNames[Language = "Русский" ? "ru" : "en"][2] "|" WeaponModeNames[Language = "Русский" ? "ru" : "en"][3] "|" WeaponModeNames[Language = "Русский" ? "ru" : "en"][4]
    GuiControl,, WPSelectedMode, %ModeListString%
    GuiControl, Choose, WPSelectedMode, % WeaponModeNames[Language = "Русский" ? "ru" : "en"][CurrentWeaponMode]
    GuiControl,, WPChargePercentInput, %UnsafeChargePercent%
    ; Hotkey, LButton, LButtonMacro, Off
}

InitActivationModeGUIControls()
{
    global ActivationModeNames, Language, CurrentActivationMode 
	; Clear the existing list before adding new items
    GuiControl,, SelectedActivationMode, |
	ActivationModeListString := ActivationModeNames[Language = "Русский" ? "ru" : "en"][1] "|" ActivationModeNames[Language = "Русский" ? "ru" : "en"][2] "|" ActivationModeNames[Language = "Русский" ? "ru" : "en"][3] "|" ActivationModeNames[Language = "Русский" ? "ru" : "en"][4] "|" ActivationModeNames[Language = "Русский" ? "ru" : "en"][5]
    GuiControl,, SelectedActivationMode, %ActivationModeListString%
    GuiControl, Choose, SelectedActivationMode, %CurrentActivationMode%
}

SaveWPSettings:
    Gui, Submit, NoHide
    UpdateAndValidateChargePercent()
    SaveWeaponSettings()
    
    ; Выключаем старые хоткеи
    for each, hk in [ToggleWeaponHotkey, CycleWeaponModeHotkey, DriverAssistHotkey, WeaponAssistHotkey, SafetyHotkey] {
        if (hk != "")
            Hotkey, %hk%, Off
    }

    hotkeys := ["ToggleWeaponHotkey", "CycleWeaponModeHotkey", "DriverAssistHotkey", "WeaponAssistHotkey", "SafetyHotkey"]
    inputs  := ["WPToggleScriptInput", "WPCycleModeInput", "WPDriverAssistHotkeyControl", "WPWeaponAssistInput", "WPSafetyHotkeyInput"]
    choices := ["WPButton1MouseChoice", "WPButton2MouseChoice", "WPButton3MouseChoice", "WPWeaponAssistMouseChoice", "WPSafetyMouseChoice"]
    wilds   := ["WPToggleWildcard", "WPCycleWildcard", "WPDriverWildcard", "WPWeaponAssistWildcard", "WPSafetyWildcard"]
    funcs   := ["ToggleWeaponFunc", "CycleWeaponModeFunc", "ToggleDriverFunc", "LButtonMacro", "WPSafetyHotkeyFunc"]
    
    Loop, % hotkeys.Length() {
        idx := A_Index
        varName := hotkeys[idx]
        inputName := inputs[idx]
        choiceName := choices[idx]
        wildName := wilds[idx]
        funcName := funcs[idx]

        ; Выбираем значение из DropDownList или Hotkey поля
        if (%choiceName% != "[Input]")
            %varName% := %choiceName%
        else
            %varName% := %inputName%

        ; Применяем wildcard
        %varName% := ApplyWildcard(%varName%, %wildName%)
		
		if (varName = "SafetyHotkey") {
            HotkeyVal := %varName% ; Используем локальную переменную
            
            ; Проверяем, был ли Wildcard (*) применен функцией ApplyWildcard
            if (SubStr(HotkeyVal, 1, 1) = "*") {
                ; Если * есть, заменяем его на ~
                HotkeyVal := "~" . SubStr(HotkeyVal, 2) 
            }
            ; *** Если * не было, мы НЕ добавляем ~ (оставляем HotkeyVal как есть) ***
            
            ; Обновляем глобальную переменную SafetyHotkey
            %varName% := HotkeyVal 
        }

        ; Сохраняем в ini
        IniWrite, % %varName%, %IniFile%, WeaponHotkeys, %varName%
        IniWrite, % %wildName%, %IniFile%, WeaponHotkeys, %wildName%
        
        ; Включаем хоткей, если он задан
        if (%varName% != "") {
            Hotkey, % %varName%, %funcName%, On
            ; === Специальная логика для предохранителя ===
            if (varName = "SafetyHotkey") {
                Hotkey, %SafetyHotkey% Up, WPSafetyHotkeyFunc_Release, On
            }
        }
    }
	WeaponAssistantActive := false
    UpdateWeaponStatus()

	MsgBox, 64, % (Language = "Русский" ? "Настройки ассистента оружия применены!" : "Weapon Assistant settings applied!"), % (Language = "Русский"
        ? "Значения сохранены и применены:`n`n"
		. "Режим оружия: " . CurrentWeaponMode . "`n"
		. "Заряд Рельсотрона: " . UnsafeChargePercent . "%" . "`n"
		. "Ассистент Оружия: " . ToggleWeaponHotkey . "`n"
		. "Ассистент Выстрел: " . WeaponAssistHotkey . "`n"
		. "Ассистент Предохранитель: " . SafetyHotkey . "`n"
        . "Переключение Режимов: " . CycleWeaponModeHotkey . "`n"
        . "Ассистент Вождения: " . DriverAssistHotkey
        : "Values ​​saved and applied:`n`n"
		. "Weapon mode: " . CurrentWeaponMode . "`n"
		. "Railgun Charge: " . UnsafeChargePercent . "%" . "`n"
		. "Weapon Assistant: " . ToggleWeaponHotkey . "`n"
		. "Assistant Fire Button: " . WeaponAssistHotkey . "`n"
		. "Assistant Safety Button: " . SafetyHotkey . "`n"
        . "Mode Switching: " . CycleWeaponModeHotkey . "`n"
        . "Driver Assistant: " . DriverAssistHotkey)
Return

SaveWeaponSettings()
{
    global IniFile, CurrentWeaponMode, UnsafeChargePercent
    IniWrite, %CurrentWeaponMode%, %IniFile%, WeaponSettings, CurrentWeaponMode
    IniWrite, %UnsafeChargePercent%, %IniFile%, WeaponSettings, UnsafeChargePercent
}

LoadWPHotkeys() {
    global ToggleWeaponHotkey, CycleWeaponModeHotkey, DriverAssistHotkey, WeaponAssistHotkey, SafetyHotkey
    global WPToggleWildcard, WPCycleWildcard, WPDriverWildcard, WPWeaponAssistWildcard, WPSafetyWildcard
    global IniFile

    hotkeys     := ["ToggleWeaponHotkey", "CycleWeaponModeHotkey", "DriverAssistHotkey", "WeaponAssistHotkey", "SafetyHotkey"]
    wildcards   := ["WPToggleWildcard", "WPCycleWildcard", "WPDriverWildcard", "WPWeaponAssistWildcard", "WPSafetyWildcard"]
    funcs       := ["ToggleWeaponFunc", "CycleWeaponModeFunc", "ToggleDriverFunc", "LButtonMacro", "WPSafetyHotkeyFunc"]

    Loop, % hotkeys.Length() {
        idx := A_Index
        varName := hotkeys[idx]
        wildName := wildcards[idx]
        funcName := funcs[idx]

        ; Чтение из ini
        IniRead, temp, %IniFile%, WeaponHotkeys, %varName%, ERROR
        IniRead, tempWild, %IniFile%, WeaponHotkeys, %wildName%, 0
        
        if (temp != "ERROR") {
            if (tempWild = 1) {
                %wildName% := 1
            } else {
                %wildName% := 0
            }
            %varName% := temp
        } else {
            ; Значение не найдено, устанавливаем по умолчанию
            %varName% := ""
            %wildName% := 0
        }

        ; Активируем хоткей
        if (%varName% != "") {
            Hotkey, % %varName%, %funcName%, On
            ; === Специальная логика для предохранителя ===
            if (varName = "SafetyHotkey") {
                Hotkey, %SafetyHotkey% Up, WPSafetyHotkeyFunc_Release, On
            }
        }
    }
}


ApplyAllHotkeys:
    Gui, Submit, NoHide ; обновит все переменные
    ; Сначала получаем значения со ВСЕХ полей GUI.
    ; --- 1. Логика для ProfileNextHotkey ---
    ProfileNextHotkey := Trim(ProfileNextHotkeyControl) ; Получаем значение из контрола и очищаем
    IniWrite, %ProfileNextHotkey%, %IniFile%, Config, ProfileNextHotkey ; Сохраняем в INI-файл
    ; --- 2. Логика для ProfilePrevHotkey ---
    ProfilePrevHotkey := Trim(ProfilePrevHotkeyControl) ; Получаем значение из контрола и очищаем
    IniWrite, %ProfilePrevHotkey%, %IniFile%, Config, ProfilePrevHotkey ; Сохраняем в INI-файл
    ; --- 3. Логика для SuspendHotkey ---
    SuspendHotkey := Trim(SuspendHotkeyControl) ; Получаем значение из контрола
    IniWrite, %SuspendHotkey%, %IniFile%, Config, SuspendHotkey ; Сохраняем в INI-файл
	; --- 4. Логика для FloatingWindowHotkey ---
	FloatingWindowHotkey := Trim(FloatingHotkeyControl)
	IniWrite, %FloatingWindowHotkey%, %IniFile%, Config, FloatingWindowHotkey
	; --- 5. Логика для ExitHotkey ---
    ExitHotkey := Trim(ExitHotkeyControl) ; Получаем значение из контрола
    IniWrite, %ExitHotkey%, %IniFile%, Config, ExitHotkey ; Сохраняем в INI-файл

    ; --- ПРИМЕНЯЕМ ВСЕ ИЗМЕНЕНИЯ ГОРЯЧИХ КЛАВИШ ---
    ; Вызываем ВАШИ СУЩЕСТВУЮЩИЕ функции.
    SetProfileSwitchHotkeys()   ; функция для профильных хоткеев
    SetSuspendHotkey()          ; функция для Suspend хоткея
	SetExitHotkey()          	; функция для Exit хоткея
	SetFloatingWindowHotkey() 	; функция для FloatingWindow хоткея

    ; --- Уведомление с отображением всех заданных горячих клавиш ---
    MsgBox, 64, % (Language = "Русский" ? "Настройки применены" : "Settings Applied"), % (Language = "Русский"
        ? "Горячие клавиши сохранены и применены:`n"
		. "Вкл/Выкл скрипта: " . SuspendHotkey . "`n"
		. "Закрыть скрипт: " . ExitHotkey . "`n"
		. "Плавающее окно: " . FloatingWindowHotkey . "`n"
        . "Следующий профиль: " . ProfileNextHotkey . "`n"
        . "Предыдущий профиль: " . ProfilePrevHotkey
        : "Hotkeys saved and applied:`n"
		. "Script Toggle: " . SuspendHotkey . "`n"
		. "Exit script: " . ExitHotkey . "`n"
		. "Floating Window: " . FloatingWindowHotkey . "`n"
        . "Next Profile: " . ProfileNextHotkey . "`n"
        . "Previous Profile: " . ProfilePrevHotkey)
Return

SetProfileSwitchHotkeys()
{
    global ProfileNextHotkey, ProfilePrevHotkey
    ; Используем статичные переменные, чтобы помнить ПОСЛЕДНЮЮ успешно установленную горячую клавишу
    static CurrentActiveNextHotkey := ""
    static CurrentActivePrevHotkey := ""

    ; --- Управление горячей клавишей "Следующий профиль" ---
    ; Отключить SPECIFIC hotkey, который был ранее активен для NEXT.
    if (CurrentActiveNextHotkey != "") {
        Hotkey, %CurrentActiveNextHotkey%, ProfileNextHotkeyAction, Off
    }

    ; Если новая ProfileNextHotkey не пуста, включить её.
    if (ProfileNextHotkey != "") {
        Hotkey, %ProfileNextHotkey%, ProfileNextHotkeyAction, On
        CurrentActiveNextHotkey := ProfileNextHotkey ; Запоминаем эту горячую клавишу как активную
    } else {
        CurrentActiveNextHotkey := "" ; Если новая горячая клавиша пуста, очищаем трекер
    }

    ; --- Управление горячей клавишей "Предыдущий профиль" ---
    ; Отключить SPECIFIC hotkey, который был ранее активен для PREV.
    if (CurrentActivePrevHotkey != "") {
        Hotkey, %CurrentActivePrevHotkey%, ProfilePrevHotkeyAction, Off
    }

    ; Если новая ProfilePrevHotkey не пуста, включить её.
    if (ProfilePrevHotkey != "") {
        Hotkey, %ProfilePrevHotkey%, ProfilePrevHotkeyAction, On
        CurrentActivePrevHotkey := ProfilePrevHotkey ; Запоминаем эту горячую клавишу как активную
    } else {
        CurrentActivePrevHotkey := "" ; Если новая горячая клавиша пуста, очищаем трекер
    }
}

; === Действие горячей клавиши "Следующий профиль" ===
ProfileNextHotkeyAction:
    global ActiveProfile, Profiles, Language

    profileListString := GetProfilesList()
    profileArray := StrSplit(profileListString, "|")

    currentIndex := -1
    for i, profileName in profileArray {
        if (profileName = ActiveProfile) {
            currentIndex := i
            break
        }
    }

    if (currentIndex = -1 || profileArray.MaxIndex() = 0) {
        if (profileArray.MaxIndex() > 0)
            ActiveProfile := profileArray[1]
        else {
            MsgBox % (Language = "Русский" ? "Нет доступных профилей для переключения." : "No profiles available to switch.")
            Return
        }
    } else {
        nextIndex := currentIndex + 1
        if (nextIndex > profileArray.MaxIndex()) {
            nextIndex := 1
        }
        ActiveProfile := profileArray[nextIndex]
    }

    ActiveProfileDDL := ActiveProfile ; Важно! Эта строка обновляет переменную, которую SwitchProfile ожидает.
    GoSub, SwitchProfile
Return

; === Действие горячей клавиши "Предыдущий профиль" ===
ProfilePrevHotkeyAction:
    global ActiveProfile, Profiles, Language

    profileListString := GetProfilesList()
    profileArray := StrSplit(profileListString, "|")

    currentIndex := -1
    for i, profileName in profileArray {
        if (profileName = ActiveProfile) {
            currentIndex := i
            break
        }
    }

    if (currentIndex = -1 || profileArray.MaxIndex() = 0) {
        if (profileArray.MaxIndex() > 0)
            ActiveProfile := profileArray[1]
        else {
            MsgBox % (Language = "Русский" ? "Нет доступных профилей для переключения." : "No profiles available to switch.")
            Return
        }
    } else {
        prevIndex := currentIndex - 1
        if (prevIndex < 1) {
            prevIndex := profileArray.MaxIndex()
        }
        ActiveProfile := profileArray[prevIndex]
    }

    ActiveProfileDDL := ActiveProfile
    GoSub, SwitchProfile
Return

; ---------- Macro for Inventory Manager ----------
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

SaveDISettings:
    ; Сохраняем старые хоткеи ДО их обновления
    old1 := (DIButton1Wildcard ? "*" : "") . DIButton1Hotkey
    old2 := (DIButton2Wildcard ? "*" : "") . DIButton2Hotkey
    old3 := (DIButton3Wildcard ? "*" : "") . DIButton3Hotkey
    old4 := (DIButton4Wildcard ? "*" : "") . DIButton4Hotkey

    Gui, Submit, NoHide

    ; Отключаем СТАРЫЕ хоткеи
    if (old1 != "")
        Hotkey, %old1%, DIButton1Function, Off
    if (old2 != "")
        Hotkey, %old2%, DIButton2Function, Off
    if (old3 != "")
        Hotkey, %old3%, DIButton3Function, Off
    if (old4 != "")
        Hotkey, %old4%, DIButton4Function, Off
	
	if (DISleepDelayInput = "")
	{
        DISleepDelayInput := 25
		GuiControl,, DISleepDelayInput, %DISleepDelayInput%
	}
	if (DISleepDelayInput2 = "")
	{
        DISleepDelayInput2 := 75
		GuiControl,, DISleepDelayInput2, %DISleepDelayInput2%
	}

    ; Обновить переменные и добавить префикс '*'
    ; Обработка приоритета — используем DropDownList если он не "[Input]"
    if (DIButton1MouseChoice != "[Input]")
        DIButton1Hotkey := DIButton1MouseChoice
    else
        DIButton1Hotkey := DIButton1Input
    ; --- Добавляем префикс '*' если чекбокс отмечен ---
    if DIButton1Wildcard
        DIButton1Hotkey := "*" . DIButton1Hotkey

    if (DIButton2MouseChoice != "[Input]")
        DIButton2Hotkey := DIButton2MouseChoice
    else
        DIButton2Hotkey := DIButton2Input
    if DIButton2Wildcard
        DIButton2Hotkey := "*" . DIButton2Hotkey

    if (DIButton3MouseChoice != "[Input]")
        DIButton3Hotkey := DIButton3MouseChoice
    else
        DIButton3Hotkey := DIButton3Input
    if DIButton3Wildcard
        DIButton3Hotkey := "*" . DIButton3Hotkey

    if (DIButton4MouseChoice != "[Input]")
        DIButton4Hotkey := DIButton4MouseChoice
    else
        DIButton4Hotkey := DIButton4Input
    if DIButton4Wildcard
        DIButton4Hotkey := "*" . DIButton4Hotkey


    DISleepDelay := DISleepDelayInput + 0
	DISleepDelay2 := DISleepDelayInput2 + 0

    ; Сохраняем значения в INI-файл (теперь Hotkey может содержать *)
    IniWrite, %DIButton1Hotkey%, %IniFile%, DIHotkeys, DIButton1
    IniWrite, %DIButton2Hotkey%, %IniFile%, DIHotkeys, DIButton2
    IniWrite, %DIButton3Hotkey%, %IniFile%, DIHotkeys, DIButton3
    IniWrite, %DIButton4Hotkey%, %IniFile%, DIHotkeys, DIButton4
    IniWrite, %DISleepDelay%, %IniFile%, DIHotkeys, DISleepDelay
	IniWrite, %DISleepDelay2%, %IniFile%, DIHotkeys, DISleepDelay2
    ; --- Сохраняем состояние чекбоксов ---
    IniWrite, %DIButton1Wildcard%, %IniFile%, DIHotkeys, DIButton1WildcardState
    IniWrite, %DIButton2Wildcard%, %IniFile%, DIHotkeys, DIButton2WildcardState
    IniWrite, %DIButton3Wildcard%, %IniFile%, DIHotkeys, DIButton3WildcardState
    IniWrite, %DIButton4Wildcard%, %IniFile%, DIHotkeys, DIButton4WildcardState

    ; Включаем новые хоткеи (уже с потенциальным префиксом *)
    if (DIButton1Hotkey != "")
        Hotkey, %DIButton1Hotkey%, DIButton1Function, On
    if (DIButton2Hotkey != "")
        Hotkey, %DIButton2Hotkey%, DIButton2Function, On
    if (DIButton3Hotkey != "")
        Hotkey, %DIButton3Hotkey%, DIButton3Function, On
    if (DIButton4Hotkey != "")
        Hotkey, %DIButton4Hotkey%, DIButton4Function, On

    MsgBox, 64, % (Language = "Русский" ? "Функции инвентаря" : "Inventory Functions"), % (Language = "Русский"
        ? "Настройки сохранены и применены:`n`n"
		. "Скинуть Рюкзак: " . DIButton1Hotkey . "`n"
        . "Выбросить Оружие: " . DIButton2Hotkey . "`n"
        . "Выбросить Кейс: " . DIButton3Hotkey . "`n"
        . "Выбросить Образцы: " . DIButton4Hotkey . "`n"
		. "Задержка после нажатия клавиши(X): " . DISleepDelay . "мс" . "`n"
		. "Задержка перед отпусканием клавиши(X): " . DISleepDelay2 . "мс"
        : "Settings Saved and Applied:`n`n"
		. "Drop Backpack: " . DIButton1Hotkey . "`n"
        . "Drop Weapon: " . DIButton2Hotkey . "`n"
        . "Drop Suitcase: " . DIButton3Hotkey . "`n"
        . "Drop Samples: " . DIButton4Hotkey . "`n"
		. "Delay after keypress(X): " . DISleepDelay . "ms" . "`n"
		. "Delay before key release(X): " . DISleepDelay2 . "ms")
Return

; --- Configuration Function (Loads from settings.ini and Activates Hotkeys) ---
LoadDISettings() {
    global DIButton1Hotkey, DIButton2Hotkey, DIButton3Hotkey, DIButton4Hotkey
    global DISleepDelay, DISleepDelay2
    global DIButton1Wildcard, DIButton2Wildcard, DIButton3Wildcard, DIButton4Wildcard

    ; Инициализация переменных состояния Wildcard (по умолчанию выключены)
    DIButton1Wildcard := 0
    DIButton2Wildcard := 0
    DIButton3Wildcard := 0
    DIButton4Wildcard := 0

    ; Попытка прочитать каждое значение из INI-файла
    IniRead, temp1, %IniFile%, DIHotkeys, DIButton1, ERROR
    IniRead, temp2, %IniFile%, DIHotkeys, DIButton2, ERROR
    IniRead, temp3, %IniFile%, DIHotkeys, DIButton3, ERROR
    IniRead, temp4, %IniFile%, DIHotkeys, DIButton4, ERROR
    IniRead, tempDelay, %IniFile%, DIHotkeys, DISleepDelay, ERROR
	IniRead, tempDelay2, %IniFile%, DIHotkeys, DISleepDelay2, ERROR
    ; Читаем сохраненное состояние чекбоксов (*-модификатора)
    IniRead, tempWildcard1, %IniFile%, DIHotkeys, DIButton1WildcardState, 0
    IniRead, tempWildcard2, %IniFile%, DIHotkeys, DIButton2WildcardState, 0
    IniRead, tempWildcard3, %IniFile%, DIHotkeys, DIButton3WildcardState, 0
    IniRead, tempWildcard4, %IniFile%, DIHotkeys, DIButton4WildcardState, 0

    ; --- Обработка DIButton1Hotkey ---
    if (temp1 != "ERROR") {
        ; Проверяем, начинается ли Hotkey с '*'
        if SubStr(temp1, 1, 1) = "*" {
            DIButton1Hotkey := SubStr(temp1, 2) ; Удаляем '*' из строки
            DIButton1Wildcard := 1              ; Устанавливаем Wildcard в 1
        } else {
            DIButton1Hotkey := temp1            ; Используем Hotkey как есть
            DIButton1Wildcard := 0              ; Wildcard выключен
        }
    } else {
        DIButton1Hotkey := "" ; Если ошибка чтения, устанавливаем пустую строку
    }

    ; --- Обработка DIButton2Hotkey ---
    if (temp2 != "ERROR") {
        if SubStr(temp2, 1, 1) = "*" {
            DIButton2Hotkey := SubStr(temp2, 2)
            DIButton2Wildcard := 1
        } else {
            DIButton2Hotkey := temp2
            DIButton2Wildcard := 0
        }
    } else {
        DIButton2Hotkey := ""
    }

    ; --- Обработка DIButton3Hotkey ---
    if (temp3 != "ERROR") {
        if SubStr(temp3, 1, 1) = "*" {
            DIButton3Hotkey := SubStr(temp3, 2)
            DIButton3Wildcard := 1
        } else {
            DIButton3Hotkey := temp3
            DIButton3Wildcard := 0
        }
    } else {
        DIButton3Hotkey := ""
    }

    ; --- Обработка DIButton4Hotkey ---
    if (temp4 != "ERROR") {
        if SubStr(temp4, 1, 1) = "*" {
            DIButton4Hotkey := SubStr(temp4, 2)
            DIButton4Wildcard := 1
        } else {
            DIButton4Hotkey := temp4
            DIButton4Wildcard := 0
        }
    } else {
        DIButton4Hotkey := ""
    }

    ; --- Обработка DISleepDelay ---
    if (tempDelay != "ERROR")
        DISleepDelay := tempDelay + 0
    else
        DISleepDelay := 25 ; Значение по умолчанию, если не найдено
	
	; --- Обработка DISleepDelay2 ---
    if (tempDelay2 != "ERROR")
        DISleepDelay2 := tempDelay2 + 0
    else
        DISleepDelay2 := 75 ; Значение по умолчанию, если не найдено

    ; Обновляем состояние чекбоксов в GUI после загрузки
    DIButton1Wildcard := tempWildcard1 + 0
    DIButton2Wildcard := tempWildcard2 + 0
    DIButton3Wildcard := tempWildcard3 + 0
    DIButton4Wildcard := tempWildcard4 + 0

    ; Активируем Hotkey с учетом модификатора '*'
    actual_DIButton1Hotkey := (DIButton1Wildcard ? "*" : "") . DIButton1Hotkey
    if (actual_DIButton1Hotkey != "")
        Hotkey, %actual_DIButton1Hotkey%, DIButton1Function, On

    actual_DIButton2Hotkey := (DIButton2Wildcard ? "*" : "") . DIButton2Hotkey
    if (actual_DIButton2Hotkey != "")
        Hotkey, %actual_DIButton2Hotkey%, DIButton2Function, On

    actual_DIButton3Hotkey := (DIButton3Wildcard ? "*" : "") . DIButton3Hotkey
    if (actual_DIButton3Hotkey != "")
        Hotkey, %actual_DIButton3Hotkey%, DIButton3Function, On

    actual_DIButton4Hotkey := (DIButton4Wildcard ? "*" : "") . DIButton4Hotkey
    if (actual_DIButton4Hotkey != "")
        Hotkey, %actual_DIButton4Hotkey%, DIButton4Function, On
}

; Определить центр экрана
CalculateScreenCenter()
{
    ; Получаем разрешение экрана (только один раз при запуске скрипта)
    SysGet, screen_width, 0  ; Ширина основного экрана
    SysGet, screen_height, 1 ; Высота основного экрана

    ; Вычисляем центр экрана
    center_x := screen_width / 2
    center_y := screen_height / 2
}

; Перемещение мышки после центровки, с функцией подгонки под разрешение монитора
PerformMouseMovement(raw_move_x, raw_move_y)
{
    ; 1. Calculate scaling factors
    scale_x := screen_width / BASE_WIDTH
    scale_y := screen_height / BASE_HEIGHT

    ; 2. Apply scaling to the raw movement values
    scaled_move_x := raw_move_x * scale_x
    scaled_move_y := raw_move_y * scale_y

	Sleep 25
    Send {x Down}
    Sleep %DISleepDelay%
    MouseMove, %scaled_move_x%, %scaled_move_y%, 0, R
    Sleep %DISleepDelay2%
    Send {x Up}
}

WPSafetyHotkeyFunc:
    global WeaponAssistHotkey, SafetyHotkey, WeaponAssistantActive, ScriptSuspended
    
    ; Эта функция отвечает только за включение макроса
    if (WeaponAssistantActive && !ScriptSuspended) {
        if (WeaponAssistHotkey != "") {
            Hotkey, %WeaponAssistHotkey%, LButtonMacro, On
        }
    }
return

WPSafetyHotkeyFunc_Release:
    global WeaponAssistHotkey
    if (WeaponAssistHotkey != "") {
        Hotkey, %WeaponAssistHotkey%, LButtonMacro, Off
    }
return

; ---------- Main macro for Weapon Assistant ----------
LButtonMacro:
    ; Ensure this only runs if WeaponAssistantActive and the main script is not suspended
    if (!WeaponAssistantActive || ScriptSuspended)
        return

    ; Remove the asterisk and tilde from the hotkey name if they exist
    cleanHotkey := RegExReplace(A_ThisHotkey, "[~*$]")

    if (CurrentWeaponMode = 1) { ; Purifier / Arc-Thrower
        while GetKeyState(cleanHotkey, "P") {
            Send {LButton down}
            Sleep, 1050
            Send {LButton up}
            Sleep, 25
        }
    } else if (CurrentWeaponMode = 2) { ; Railgun Safe
        while GetKeyState(cleanHotkey, "P") {
            Send {LButton down}
            Sleep, 500
            Send {LButton up}
            Sleep, 25
            Send {r down}
            Sleep, 25
            Send {r up}
            Sleep, 1200
        }
    } else if (CurrentWeaponMode = 3) { ; Railgun Unsafe (%-dependent)
        chargeTime := 2940 * (UnsafeChargePercent / 100.0)
        while GetKeyState(cleanHotkey, "P") {
            Send {LButton down}
            Sleep, %chargeTime%
            Send {LButton up}
            Sleep, 10
            Send {r down}
            Sleep, 25
            Send {r up}
            Sleep, 1200
        }
    } else if (CurrentWeaponMode = 4) { ; Epoch
        while GetKeyState(cleanHotkey, "P") {
            Send {LButton down}
            Sleep, 2510
            Send {LButton up}
            Sleep, 25
        }
    }
Return

; ---------- Macro for Driver Assistant(Auto) ----------
; --- Macro for 'W' key ---
DriverMacroW:
    ; Проверяем, была ли последняя нажата клавиша 'W'.
    ; Если да, выходим из макроса, чтобы пропустить повторное нажатие.
    If (LastKey = "w") {
        Return
    }
    ; Иначе, обновляем переменную LastKey и выполняем макрос.
    LastKey := "w"
    
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
    KeyWait, w
Return

; --- Macro for 'S' key ---
DriverMacroS:
    ; Проверяем, была ли последняя нажата клавиша 'S'.
    ; Если да, выходим из макроса, чтобы пропустить повторное нажатие.
    If (LastKey = "s") {
        Return
    }
    ; Иначе, обновляем переменную LastKey и выполняем макрос.
    LastKey := "s"
    
    Loop 4
    {
        SendInput {Ctrl down}
        Sleep 25
        SendInput {Ctrl up}
        Sleep 25
    }
    KeyWait, s
Return

; --- Macro for 'E' key ---
DriverMacroE:
    DriverAssistantActive := false
    UpdateDriverStatus()
Return

; ---------- Macro for Driver Assistant(Manual) ----------
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

; ФУНКЦИЯ ДЛЯ ВВОДА ПОСЛЕДОВАТЕЛЬНОСТИ
ExecuteSequence(Sequence) {
    global InputMode, RealKeyDelay
    keyMap := (InputMode = "WASD")
        ? {Down:"s", Up:"w", Left:"a", Right:"d"}
        : {Down:"Down", Up:"Up",Left:"Left", Right:"Right"}

    for _, dir in Sequence {
        realKey := keyMap[dir]
        SendInput, {Blind}{%realKey% Down}
        Sleep, RealKeyDelay ; Используем глобальную задержку RealKeyDelay
        SendInput, {Blind}{%realKey% Up}
        Sleep, RealKeyDelay
    }
}

; Обработка заказов
StratagemHandler:
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
    } else if (Stratagem = "weapon_railgun_safe") {
        ; Execute Railgun Safe logic
		While GetKeyState(ThisKey, "P") {
        Send {LButton down}
        Sleep, 500
        Send {LButton up}
        Sleep, 25
        Send {r down}
        Sleep, 25
        Send {r up}
        Sleep, 1200
		}
        return
    } else if (Stratagem = "weapon_railgun_unsafe") {
        ; Execute Railgun Unsafe logic
        global UnsafeChargePercent
        chargeTime := 2940 * (UnsafeChargePercent / 100.0)
        Send {LButton down}
        Sleep, %chargeTime%
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

    global CurrentActivationMode, ActivationKey, ActivationKeyDelay, RealKeyDelay

    ; Выполняем нажатия ActivationKey в соответствии с выбранным режимом(Сравниваем с числовыми индексами)
    ; А ЗАТЕМ вызываем функцию для ввода последовательности.
    if (CurrentActivationMode = 1) { ; Tap
        SendInput, {%ActivationKey% Down}
        Sleep, 25
        SendInput, {%ActivationKey% Up}
        Sleep, ActivationKeyDelay ; Глобальная пауза ActivationKeyDelay перед вводом
        ExecuteSequence(Sequence)
    }
    else if (CurrentActivationMode = 2) { ; Double Tap
        SendInput, {%ActivationKey% Down}
        Sleep, 25
        SendInput, {%ActivationKey% Up}
        Sleep, 25
        SendInput, {%ActivationKey% Down}
        Sleep, 25
        SendInput, {%ActivationKey% Up}
        Sleep, ActivationKeyDelay
        ExecuteSequence(Sequence)
    }
    else if (CurrentActivationMode = 3) { ; Press
        SendInput, {%ActivationKey% Down}
        Sleep, 25
        SendInput, {%ActivationKey% Up}
        Sleep, ActivationKeyDelay
        ExecuteSequence(Sequence)
    }
    else if (CurrentActivationMode = 4) { ; Long Press
        SendInput, {%ActivationKey% Down}
        Sleep, 300
        SendInput, {%ActivationKey% Up}
        Sleep, ActivationKeyDelay
        ExecuteSequence(Sequence)
    }
    else if (CurrentActivationMode = 5) { ; Hold
        SendInput, {%ActivationKey% Down}
        Sleep, ActivationKeyDelay
        ExecuteSequence(Sequence)
        SendInput, {%ActivationKey% Up}
    }
return

; === Stratagems ===
LoadStratagems(lang) {
    global Stratagems, StratagemNames, OrderedStratagems
    Stratagems := Object()
    StratagemNames := Object()
    OrderedStratagems := []

    ; === CATEGORY: Defensive Stratagems ===
    id := "category_defensive_stratagems"
    Stratagems[id] := []
    StratagemNames[id] := { English: "--- Defensive Stratagems ---", Русский: "--- Стратагемы Защиты ---" }
    OrderedStratagems.Push(id)

    id := "gatling_sentry"
    Stratagems[id] := ["Down", "Up", "Right", "Left"]
    StratagemNames[id] := { English: "A/G-16 Gatling Sentry", Русский: "A/G-16 «Турель Гатлинга»" }
    OrderedStratagems.Push(id)

    id := "machine_sentry"
    Stratagems[id] := ["Down", "Up", "Right", "Right", "Up"]
    StratagemNames[id] := { English: "A/MG-43 Machine Sentry", Русский: "A/MG-43 «Пулеметная Турель»" }
    OrderedStratagems.Push(id)

    id := "flame_sentry"
    Stratagems[id] := ["Down", "Up", "Right", "Down", "Up", "Up"]
    StratagemNames[id] := { English: "A/FLAM-40 Flame Sentry", Русский: "A/FLAM-40 «Турель-Огнемет»" }
    OrderedStratagems.Push(id)

    id := "laser_sentry"
    Stratagems[id] := ["Down", "Up", "Right", "Down", "Up", "Right"]
    StratagemNames[id] := { English: "A/LAS-98 Laser Sentry", Русский: "A/LAS-98 «Лазерная Турель»" }
    OrderedStratagems.Push(id)

    id := "rocket_sentry"
    Stratagems[id] := ["Down", "Up", "Right", "Right", "Left"]
    StratagemNames[id] := { English: "A/MLS-4X Rocket Sentry", Русский: "A/MLS-4X «Ракетная Турель»" }
    OrderedStratagems.Push(id)

    id := "autocannon_sentry"
    Stratagems[id] := ["Down", "Up", "Right", "Up", "Left", "Up"]
    StratagemNames[id] := { English: "A/AC-8 Autocannon Sentry", Русский: "A/AC-8 «Турель с Автопушкой»" }
    OrderedStratagems.Push(id)

    id := "ems_sentry"
    Stratagems[id] := ["Down", "Up", "Right", "Down", "Right"]
    StratagemNames[id] := { English: "A/M-23 EMS Sentry", Русский: "A/M-23 «Турель с ЭМ-Минометом»" }
    OrderedStratagems.Push(id)

    id := "mortar_sentry"
    Stratagems[id] := ["Down", "Up", "Right", "Right", "Down"]
    StratagemNames[id] := { English: "A/M-12 Mortar Sentry", Русский: "A/M-12 «Турель с Минометом»" }
    OrderedStratagems.Push(id)

    id := "shield_generator_relay"
    Stratagems[id] := ["Down", "Down", "Left", "Right", "Left", "Right"]
    StratagemNames[id] := { English: "FX-12 Shield Generator Relay", Русский: "FX-12 «Реле Генератора Щита»" }
    OrderedStratagems.Push(id)

    id := "grenadier_battlement"
    Stratagems[id] := ["Down", "Right", "Down", "Left", "Right"]
    StratagemNames[id] := { English: "E/GL-21 Grenadier Battlement", Русский: "E/GL-21 «Амбразура Гранатометчика»" }
    OrderedStratagems.Push(id)

    id := "anti_tank_emplacement"
    Stratagems[id] := ["Down", "Up", "Left", "Right", "Right", "Right"]
    StratagemNames[id] := { English: "E/AT-12 Anti-Tank Emplacement", Русский: "E/AT-12 «Противотанковое Орудие»" }
    OrderedStratagems.Push(id)

    id := "hmg_emplacement"
    Stratagems[id] := ["Down", "Up", "Left", "Right", "Right", "Left"]
    StratagemNames[id] := { English: "E/MG-101 HMG Emplacement", Русский: "E/MG-101 «Огневая Позиция: Тяжелый Пулемет»" }
    OrderedStratagems.Push(id)

    id := "tesla_tower"
    Stratagems[id] := ["Down", "Up", "Right", "Up", "Left", "Right"]
    StratagemNames[id] := { English: "A/ARC-3 Tesla Tower", Русский: "A/ARC-3 «Тесла-Башня»" }
    OrderedStratagems.Push(id)

    id := "anti_tank_mines"
    Stratagems[id] := ["Down", "Left", "Up", "Up"]
    StratagemNames[id] := { English: "MD-17 Anti-Tank Mines", Русский: "MD-17 «Противотанковые Мины»" }
    OrderedStratagems.Push(id)

    id := "gas_mines"
    Stratagems[id] := ["Down", "Left", "Left", "Right"]
    StratagemNames[id] := { English: "MD-8 Gas Mines", Русский: "MD-8 «Газовые Мины»" }
    OrderedStratagems.Push(id)

    id := "anti_personnel_minefield"
    Stratagems[id] := ["Down", "Left", "Up", "Right"]
    StratagemNames[id] := { English: "MD-6 Anti-Personnel Minefield", Русский: "MD-6 «Противопехотные Мины»" }
    OrderedStratagems.Push(id)

    id := "incendiary_mines"
    Stratagems[id] := ["Down", "Left", "Left", "Down"]
    StratagemNames[id] := { English: "MD-14 Incendiary Mines", Русский: "MD-14 «Зажигательные Мины»" }
    OrderedStratagems.Push(id)

    ; Separator
    id := "separator_1"
    Stratagems[id] := []
    StratagemNames[id] := { English: " ", Русский: " " }
    OrderedStratagems.Push(id)

    ; === CATEGORY: Offensive Stratagems ===
    id := "category_offensive_stratagems"
    Stratagems[id] := []
    StratagemNames[id] := { English: "--- Offensive Stratagems ---", Русский: "--- Стратагемы Атаки ---" }
    OrderedStratagems.Push(id)

	id := "orbital_precision_strike"
    Stratagems[id] := ["Right", "Right", "Up"]
    StratagemNames[id] := { English: "Orbital Precision Strike", Русский: "Орбитальный Высокоточный Удар" }
    OrderedStratagems.Push(id)

    id := "orbital_gatling_barrage"
    Stratagems[id] := ["Right", "Down", "Left", "Up", "Up"]
    StratagemNames[id] := { English: "Orbital Gatling Barrage", Русский: "Орбитальный Залп Гатлинга" }
    OrderedStratagems.Push(id)

    id := "orbital_airburst_strike"
    Stratagems[id] := ["Right", "Right", "Right"]
    StratagemNames[id] := { English: "Orbital Airburst Strike", Русский: "Орбитальная Воздушная Бомба" }
    OrderedStratagems.Push(id)

    id := "orbital_napalm_barrage"
    Stratagems[id] := ["Right", "Right", "Down", "Left", "Right", "Up"]
    StratagemNames[id] := { English: "Orbital Napalm Barrage", Русский: "Орбитальный Удар Напалмом" }
    OrderedStratagems.Push(id)

    id := "orbital_120mm_he_barrage"
    Stratagems[id] := ["Right", "Right", "Down", "Left", "Right", "Down"]
    StratagemNames[id] := { English: "Orbital 120mm HE Barrage", Русский: "Орбитальный Залп 120-мм ОФ" }
    OrderedStratagems.Push(id)

    id := "orbital_walking_barrage"
    Stratagems[id] := ["Right", "Down", "Right", "Down", "Right", "Down"]
    StratagemNames[id] := { English: "Orbital Walking Barrage", Русский: "Орбитальный Огневой Вал" }
    OrderedStratagems.Push(id)

    id := "orbital_380mm_hs_barrage"
    Stratagems[id] := ["Right", "Down", "Up", "Up", "Left", "Down", "Down"]
    StratagemNames[id] := { English: "Orbital 380mm HS Barrage", Русский: "Орбитальный Залп 380-мм ОФ" }
    OrderedStratagems.Push(id)

    id := "orbital_rail_cannon_strike"
    Stratagems[id] := ["Right", "Up", "Down", "Down", "Right"]
    StratagemNames[id] := { English: "Orbital Rail Cannon Strike", Русский: "Орбитальный Рельсотронный Залп" }
    OrderedStratagems.Push(id)

    id := "orbital_laser"
    Stratagems[id] := ["Right", "Down", "Up", "Right", "Down"]
    StratagemNames[id] := { English: "Orbital Laser", Русский: "Орбитальный Лазер" }
    OrderedStratagems.Push(id)

    id := "orbital_ems_strike"
    Stratagems[id] := ["Right", "Right", "Left", "Down"]
    StratagemNames[id] := { English: "Orbital EMS Strike", Русский: "Орбитальный ЭМ-Удар" }
    OrderedStratagems.Push(id)

    id := "orbital_gas_strike"
    Stratagems[id] := ["Right", "Right", "Down", "Right"]
    StratagemNames[id] := { English: "Orbital Gas Strike", Русский: "Орбитальный Газовый Удар" }
    OrderedStratagems.Push(id)

    id := "orbital_smoke_strike"
    Stratagems[id] := ["Right", "Right", "Down", "Up"]
    StratagemNames[id] := { English: "Orbital Smoke Strike", Русский: "Орбитальная Дымовая Завеса" }
    OrderedStratagems.Push(id)

    id := "eagle_500kg_bomb"
    Stratagems[id] := ["Up", "Right", "Down", "Down", "Down"]
    StratagemNames[id] := { English: "Eagle 500kg Bomb", Русский: "Орел: Бомба (500 кг)" }
    OrderedStratagems.Push(id)

    id := "eagle_strafing_run"
    Stratagems[id] := ["Up", "Right", "Right"]
    StratagemNames[id] := { English: "Eagle Strafing Run", Русский: "Орел: Бреющий Полет" }
    OrderedStratagems.Push(id)

    id := "eagle_110mm_rockets"
    Stratagems[id] := ["Up", "Right", "Up", "Left"]
    StratagemNames[id] := { English: "Eagle 110mm Rockets", Русский: "Орел: 110-мм Ракетные Блоки" }
    OrderedStratagems.Push(id)

    id := "eagle_airstrike"
    Stratagems[id] := ["Up", "Right", "Down", "Right"]
    StratagemNames[id] := { English: "Eagle Airstrike", Русский: "Орел: Воздушный Налет" }
    OrderedStratagems.Push(id)

    id := "eagle_cluster_bomb"
    Stratagems[id] := ["Up", "Right", "Down", "Down", "Right"]
    StratagemNames[id] := { English: "Eagle Cluster Bomb", Русский: "Орел: Кластерная Бомба" }
    OrderedStratagems.Push(id)

    id := "eagle_napalm"
    Stratagems[id] := ["Up", "Right", "Down", "Up"]
    StratagemNames[id] := { English: "Eagle Napalm", Русский: "Орел: Авиаудар Напалмом" }
    OrderedStratagems.Push(id)

    id := "eagle_smoke_strike"
    Stratagems[id] := ["Up", "Right", "Up", "Down"]
    StratagemNames[id] := { English: "Eagle Smoke Strike", Русский: "Орел: Дымовая Завеса" }
    OrderedStratagems.Push(id)

    id := "eagle_re_arm"
    Stratagems[id] := ["Up", "Up", "Left", "Up", "Right"]
    StratagemNames[id] := { English: "Eagle Re-arm", Русский: "Перезарядка Орла" }
    OrderedStratagems.Push(id)

    ; Separator
    id := "separator_2"
    Stratagems[id] := []
    StratagemNames[id] := { English: " ", Русский: " " }
    OrderedStratagems.Push(id)

    ; === CATEGORY: Supply Stratagems ===
    id := "category_supply_stratagems"
    Stratagems[id] := []
    StratagemNames[id] := { English: "--- Supply Stratagems ---", Русский: "--- Стратагемы Снабжения ---" }
    OrderedStratagems.Push(id)

    id := "cqc9_defoliation_tool"
    Stratagems[id] := ["Down", "Left", "Right", "Right", "Down"]
    StratagemNames[id] := { English: "CQC-9 Defoliation Tool", Русский: "CQC-9 «Дефолиатор»" }
    OrderedStratagems.Push(id)
	
	id := "cqc1_one_true_flag"
    Stratagems[id] := ["Down", "Left", "Right", "Right", "Up"]
    StratagemNames[id] := { English: "CQC-1 One True Flag", Русский: "CQC-1 «Один Истинный Флаг»" }
    OrderedStratagems.Push(id)

    id := "mg43_machine_gun"
    Stratagems[id] := ["Down", "Left", "Down", "Up", "Right"]
    StratagemNames[id] := { English: "MG-43 Machine Gun", Русский: "MG-43 «Пулемет»" }
    OrderedStratagems.Push(id)

    id := "m105_stalwart"
    Stratagems[id] := ["Down", "Left", "Down", "Up", "Up", "Left"]
    StratagemNames[id] := { English: "M-105 Stalwart", Русский: "М-105 «Доблесть»" }
    OrderedStratagems.Push(id)

    id := "mg206_heavy_machine_gun"
    Stratagems[id] := ["Down", "Left", "Up", "Down", "Down"]
    StratagemNames[id] := { English: "MG-206 Heavy Machine Gun", Русский: "MG-206 «Тяжелый Пулемет»" }
    OrderedStratagems.Push(id)

    id := "rs422_railgun"
    Stratagems[id] := ["Down", "Right", "Down", "Up", "Left", "Right"]
    StratagemNames[id] := { English: "RS-422 Railgun", Русский: "RS-422 «Рельсотрон»" }
    OrderedStratagems.Push(id)
	
	id := "s11_speargun"
    Stratagems[id] := ["Down", "Right", "Down", "Left", "Up", "Right"]
    StratagemNames[id] := { English: "S-11 Speargun", Русский: "S-11 «Гарпун»" }
    OrderedStratagems.Push(id)

    id := "apw1_anti_material_rifle"
    Stratagems[id] := ["Down", "Left", "Right", "Up", "Down"]
    StratagemNames[id] := { English: "APW-1 Anti-Material Rifle", Русский: "APW-1 «Крупнокалиберная Винтовка»" }
    OrderedStratagems.Push(id)

    id := "plas_45_epoch"
    Stratagems[id] := ["Down", "Left", "Up", "Left", "Right"]
    StratagemNames[id] := { English: "PLAS-45 Epoch", Русский: "PLAS-45 «Эпоха»" }
    OrderedStratagems.Push(id)

    id := "gl21_grenade_launcher"
    Stratagems[id] := ["Down", "Left", "Up", "Left", "Down"]
    StratagemNames[id] := { English: "GL-21 Grenade Launcher", Русский: "GL-21 «Гранатомет»" }
    OrderedStratagems.Push(id)

    id := "gl52_de_escalator"
    Stratagems[id] := ["Down", "Right", "Up", "Left", "Right"]
    StratagemNames[id] := { English: "GL-52 DE-ESCALATOR", Русский: "GL-52 «Деэскалатор»" }
    OrderedStratagems.Push(id)

    id := "tx41_sterilizer"
    Stratagems[id] := ["Down", "Left", "Up", "Down", "Left"]
    StratagemNames[id] := { English: "TX-41 Sterilizer", Русский: "TX-41 «Стерилизатор»" }
    OrderedStratagems.Push(id)

    id := "flam40_flamethrower"
    Stratagems[id] := ["Down", "Left", "Up", "Down", "Up"]
    StratagemNames[id] := { English: "FLAM-40 Flamethrower", Русский: "FLAM-40 «Огнемет»" }
    OrderedStratagems.Push(id)

    id := "las98_laser_cannon"
    Stratagems[id] := ["Down", "Left", "Down", "Up", "Left"]
    StratagemNames[id] := { English: "LAS-98 Laser Cannon", Русский: "LAS-98 «Лазерная Пушка»" }
    OrderedStratagems.Push(id)

    id := "las99_quasar_cannon"
    Stratagems[id] := ["Down", "Down", "Up", "Left", "Right"]
    StratagemNames[id] := { English: "LAS-99 Quasar Cannon", Русский: "LAS-99 Пушка «Квазар»" }
    OrderedStratagems.Push(id)

    id := "arc3_arc_thrower"
    Stratagems[id] := ["Down", "Right", "Down", "Up", "Left", "Left"]
    StratagemNames[id] := { English: "ARC-3 Arc Thrower", Русский: "ARC-3 «Дуговой Метатель»" }
    OrderedStratagems.Push(id)

    id := "mls4x_commando"
    Stratagems[id] := ["Down", "Left", "Up", "Down", "Right"]
    StratagemNames[id] := { English: "MLS-4X Commando", Русский: "MLS-4X «Коммандос»" }
    OrderedStratagems.Push(id)
	
	id := "eat700_expendable_napalm"
    Stratagems[id] := ["Down", "Down", "Left", "Up", "Left"]
    StratagemNames[id] := { English: "EAT-700 Expendable Napalm", Русский: "EAT-700 «Одноразовый Напалм»" }
    OrderedStratagems.Push(id)
	
	id := "ms11_solo_silo"
    Stratagems[id] := ["Down", "Up", "Right", "Down", "Down"]
    StratagemNames[id] := { English: "MS-11 Solo Silo", Русский: "MS-11 «Одиночная Пусковая Шахта»" }
    OrderedStratagems.Push(id)

    id := "eat17_expendable_anti_tank"
    Stratagems[id] := ["Down", "Down", "Left", "Up", "Right"]
    StratagemNames[id] := { English: "EAT-17 Expendable Anti-Tank", Русский: "EAT-17 «Одноразовый Бронебой»" }
    OrderedStratagems.Push(id)

    id := "ac8_autocannon"
    Stratagems[id] := ["Down", "Left", "Down", "Up", "Up", "Right"]
    StratagemNames[id] := { English: "AC-8 Autocannon", Русский: "AC-8 «Автопушка»" }
    OrderedStratagems.Push(id)

    id := "rl77_airburst_rocket_launcher"
    Stratagems[id] := ["Down", "Up", "Up", "Left", "Right"]
    StratagemNames[id] := { English: "RL-77 Airburst Rocket Launcher", Русский: "RL-77 «Ракетница С Подрывом В Воздухе»" }
    OrderedStratagems.Push(id)

    id := "faf14_spear_launcher"
    Stratagems[id] := ["Down", "Down", "Up", "Down", "Down"]
    StratagemNames[id] := { English: "FAF-14 Spear Launcher", Русский: "FAF-14 «Копье»" }
    OrderedStratagems.Push(id)

    id := "sta_x3_wasp_launcher"
    Stratagems[id] := ["Down", "Down", "Up", "Down", "Right"]
    StratagemNames[id] := { English: "StA-X3 W.A.S.P. Launcher", Русский: "Ракетница StA-X3 W.A.S.P." }
    OrderedStratagems.Push(id)

    id := "m1000_maxigun"
    Stratagems[id] := ["Down", "Left", "Right", "Down", "Up", "Up"]
    StratagemNames[id] := { English: "M-1000 Maxigun", Русский: "M-1000 «Максиган»" }
    OrderedStratagems.Push(id)
	
	id := "gr8_recoiless_rifle"
    Stratagems[id] := ["Down", "Left", "Right", "Right", "Left"]
    StratagemNames[id] := { English: "GR-8 Recoiless Rifle", Русский: "GR-8 «Безоткатная Винтовка»" }
    OrderedStratagems.Push(id)

    id := "b1_supply_pack"
    Stratagems[id] := ["Down", "Left", "Down", "Up", "Up", "Down"]
    StratagemNames[id] := { English: "B-1 Supply Pack", Русский: "В-1 «Рюкзак: Боеприпасы»" }
    OrderedStratagems.Push(id)

    id := "b100_portable_hellbomb"
    Stratagems[id] := ["Down", "Right", "Up", "Up", "Up"]
    StratagemNames[id] := { English: "B-100 Portable Hellbomb", Русский: "В-100 «Переносная Адская Бомба»" }
    OrderedStratagems.Push(id)

    id := "lift182_warp_pack"
    Stratagems[id] := ["Down", "Left", "Right", "Down", "Left", "Right"]
    StratagemNames[id] := { English: "LIFT-182 Warp Pack", Русский: "LIFT-182 «Варп-Ранец»" }
    OrderedStratagems.Push(id)

    id := "lift860_hover_pack"
    Stratagems[id] := ["Down", "Up", "Up", "Down", "Left", "Right"]
    StratagemNames[id] := { English: "LIFT-860 Hover Pack", Русский: "LIFT-860 «Ранец Для Парения»" }
    OrderedStratagems.Push(id)

    id := "lift850_jump_pack"
    Stratagems[id] := ["Down", "Up", "Up", "Down", "Up"]
    StratagemNames[id] := { English: "LIFT-850 Jump Pack", Русский: "LIFT-850 «Реактивный Ранец»" }
    OrderedStratagems.Push(id)

    id := "sh32_shield_generator_pack"
    Stratagems[id] := ["Down", "Up", "Left", "Right", "Left", "Right"]
    StratagemNames[id] := { English: "SH-32 Shield Generator Pack", Русский: "SH-32 «Генератор Щита»" }
    OrderedStratagems.Push(id)

    id := "sh51_directional_shield"
    Stratagems[id] := ["Down", "Up", "Left", "Right", "Up", "Up"]
    StratagemNames[id] := { English: "SH-51 Directional Shield", Русский: "SH-51 «Щит Направленного Действия»" }
    OrderedStratagems.Push(id)

    id := "sh20_ballistic_shield_backpack"
    Stratagems[id] := ["Down", "Left", "Down", "Down", "Up", "Left"]
    StratagemNames[id] := { English: "SH-20 Ballistic Shield Backpack", Русский: "SH-20 «Рюкзак: Баллистический Щит»" }
    OrderedStratagems.Push(id)

    id := "ax_arc3_guard_dog_k9"
    Stratagems[id] := ["Down", "Up", "Left", "Up", "Right", "Left"]
    StratagemNames[id] := { English: "AX/ARC-3 Guard Dog K-9", Русский: "AX/ARC-3 «Сторожевой Пес» K-9 (Электро)" }
    OrderedStratagems.Push(id)
	
	id := "ax_flam75_guard_dog"
    Stratagems[id] := ["Down", "Up", "Left", "Up", "Left", "Left"]
    StratagemNames[id] := { English: "AX/FLAM-75 Guard Dog Hot Dog", Русский: "AX/FLAM-75 «Сторожевой Пес» (Огнемет)" }
    OrderedStratagems.Push(id)
	
	id := "ax_ar23_guard_dog"
    Stratagems[id] := ["Down", "Up", "Left", "Up", "Right", "Down"]
    StratagemNames[id] := { English: "AX/AR-23 Guard Dog", Русский: "AX/AR-23 «Сторожевой Пес» (Винтовка)" }
    OrderedStratagems.Push(id)

    id := "ax_las5_guard_dog_rover"
    Stratagems[id] := ["Down", "Up", "Left", "Up", "Right", "Right"]
    StratagemNames[id] := { English: "AX/LAS-5 Guard Dog Rover", Русский: "AX/LAS-5 «Сторожевой Пес» (Лазер)" }
    OrderedStratagems.Push(id)

    id := "ax_tx13_guard_dog_breath"
    Stratagems[id] := ["Down", "Up", "Left", "Up", "Right", "Up"]
    StratagemNames[id] := { English: "AX/TX-13 Guard Dog Breath", Русский: "AX/TX-13 «Сторожевой Пес» (Газ)" }
    OrderedStratagems.Push(id)

    id := "m102_fast_reconnaissance_vehicle"
    Stratagems[id] := ["Left", "Down", "Right", "Down", "Right", "Down", "Up"]
    StratagemNames[id] := { English: "M-102 Fast Reconnaissance Vehicle", Русский: "М-102 «Машина Тактической Разведки»" }
    OrderedStratagems.Push(id)

    id := "exo49_emancipator_exosuit"
    Stratagems[id] := ["Left", "Down", "Right", "Up", "Left", "Down", "Up"]
    StratagemNames[id] := { English: "EXO-49 Emancipator Exosuit", Русский: "EXO-49 Экзокостюм «Благодетель»" }
    OrderedStratagems.Push(id)

    id := "exo45_patriot_exosuit"
    Stratagems[id] := ["Left", "Down", "Right", "Up", "Left", "Down", "Down"]
    StratagemNames[id] := { English: "EXO-45 Patriot Exosuit", Русский: "EXO-45 Экзокостюм «Патриот»" }
    OrderedStratagems.Push(id)

    ; Separator
    id := "separator_3"
    Stratagems[id] := []
    StratagemNames[id] := { English: " ", Русский: " " }
    OrderedStratagems.Push(id)

    ; === CATEGORY: Mission Stratagems ===
    id := "category_mission_stratagems"
    Stratagems[id] := []
    StratagemNames[id] := { English: "--- Mission Stratagems ---", Русский: "--- Стратагемы Миссии ---" }
    OrderedStratagems.Push(id)

    id := "reinforce"
    Stratagems[id] := ["Up", "Down", "Right", "Left", "Up"]
    StratagemNames[id] := { English: "Reinforce", Русский: "Подкрепление" }
    OrderedStratagems.Push(id)

    id := "resupply"
    Stratagems[id] := ["Down", "Down", "Up", "Right"]
    StratagemNames[id] := { English: "Resupply", Русский: "Пополнение Припасов" }
    OrderedStratagems.Push(id)

    id := "nux223_hellbomb"
    Stratagems[id] := ["Down", "Up", "Left", "Down", "Up", "Right", "Down", "Up"]
    StratagemNames[id] := { English: "NUX-223 Hellbomb", Русский: "NUX-223 «Адская Бомба»" }
    OrderedStratagems.Push(id)

    id := "super_earth_flag"
    Stratagems[id] := ["Down", "Up", "Down", "Up"]
    StratagemNames[id] := { English: "Super Earth Flag", Русский: "Флаг СЗ" }
    OrderedStratagems.Push(id)

    id := "sos_beacon"
    Stratagems[id] := ["Up", "Down", "Right", "Up"]
    StratagemNames[id] := { English: "SOS Beacon", Русский: "Аварийный Маяк" }
    OrderedStratagems.Push(id)

    id := "sssd_delivery"
    Stratagems[id] := ["Down", "Down", "Down", "Up", "Up"]
    StratagemNames[id] := { English: "SSSD Delivery", Русский: "Доставка СТН" }
    OrderedStratagems.Push(id)

    id := "seismic_probe"
    Stratagems[id] := ["Up", "Up", "Left", "Right", "Down", "Down"]
    StratagemNames[id] := { English: "Seismic Probe", Русский: "Сейсмический Зонд" }
    OrderedStratagems.Push(id)

    id := "upload_data"
    Stratagems[id] := ["Left", "Right", "Up", "Up", "Up"]
    StratagemNames[id] := { English: "Upload Data", Русский: "Загрузка Данных" }
    OrderedStratagems.Push(id)

    id := "prospecting_drill"
    Stratagems[id] := ["Down", "Down", "Left", "Right", "Down", "Down"]
    StratagemNames[id] := { English: "Prospecting Drill", Русский: "Разведбур" }
    OrderedStratagems.Push(id)

    id := "dark_fluid_vessel"
    Stratagems[id] := ["Up", "Left", "Right", "Down", "Up", "Up"]
    StratagemNames[id] := { English: "Dark Fluid Vessel", Русский: "Емкость С Темной Жидкостью" }
    OrderedStratagems.Push(id)

    id := "tectonic_drill"
    Stratagems[id] := ["Up", "Down", "Up", "Down", "Up", "Down"]
    StratagemNames[id] := { English: "Tectonic Drill", Русский: "Тектонический Бур" }
    OrderedStratagems.Push(id)

    id := "hive_breaker_drill"
    Stratagems[id] := ["Left", "Up", "Down", "Right", "Down", "Down"]
    StratagemNames[id] := { English: "Hive Breaker Drill", Русский: "Бур «Крушитель Ульев»" }
    OrderedStratagems.Push(id)
	
	id := "mobile_extraction_drill"
    Stratagems[id] := ["Down", "Down", "Left", "Left", "Down", "Down"]
    StratagemNames[id] := { English: "Mobile Extraction Drill", Русский: "Бур «Мобильная Откачка»" }
    OrderedStratagems.Push(id)

    id := "seaf_artillery"
    Stratagems[id] := ["Right", "Up", "Up", "Down"]
    StratagemNames[id] := { English: "SEAF Artillery", Русский: "Артиллерия ВССЗ" }
    OrderedStratagems.Push(id)
	
	; Separator
    id := "separator_4"
    Stratagems[id] := []
    StratagemNames[id] := { English: " ", Русский: " " }
    OrderedStratagems.Push(id)
	
	; === CATEGORY: Weapon Modes ===
    id := "category_weapon_modes"
    Stratagems[id] := []
    StratagemNames[id] := { English: "--- Weapon Assistant ---", Русский: "--- Ассистент Оружия ---" }
    OrderedStratagems.Push(id)

    id := "weapon_purifier_arc"
    Stratagems[id] := ["Purifier"] ; Unique identifier for the handler
    StratagemNames[id] := { English: "Purifier/Arc-Thrower", Русский: "Очиститель/Дуговой-метатель" }
    OrderedStratagems.Push(id)

    id := "weapon_railgun_safe"
    Stratagems[id] := ["RailgunSafe"]
    StratagemNames[id] := { English: "Railgun (Safe)", Русский: "Рельсотрон (Обычный)" }
    OrderedStratagems.Push(id)

    id := "weapon_railgun_unsafe"
    Stratagems[id] := ["RailgunUnsafe"]
    StratagemNames[id] := { English: "Railgun (Unsafe)", Русский: "Рельсотрон (Убойный)" }
    OrderedStratagems.Push(id)
	
	id := "weapon_epoch"
    Stratagems[id] := ["Epoch"]
    StratagemNames[id] := { English: "Epoch", Русский: "Эпоха" }
    OrderedStratagems.Push(id)
	
	; Separator
    id := "separator_5"
    Stratagems[id] := []
    StratagemNames[id] := { English: " ", Русский: " " }
    OrderedStratagems.Push(id)
	
	; === CATEGORY: Item Drop ===
    id := "category_item_drop"
    Stratagems[id] := []
    StratagemNames[id] := { English: "--- Item Drop ---", Русский: "--- Выброс Предмета ---" }
    OrderedStratagems.Push(id)

    id := "Iteam_drop_1"
    Stratagems[id] := ["DropItem1"]
    StratagemNames[id] := { English: "Drop Backpack", Русский: "Скинуть Рюкзак" }
    OrderedStratagems.Push(id)

    id := "Iteam_drop_2"
    Stratagems[id] := ["DropItem2"]
    StratagemNames[id] := { English: "Drop Weapon", Русский: "Выбросить Оружие" }
    OrderedStratagems.Push(id)

    id := "Iteam_drop_3"
    Stratagems[id] := ["DropItem3"]
    StratagemNames[id] := { English: "Drop Suitcase", Русский: "Выбросить Кейс" }
    OrderedStratagems.Push(id)
	
	id := "Iteam_drop_4"
    Stratagems[id] := ["DropItem4"]
    StratagemNames[id] := { English: "Drop Samples", Русский: "Выбросить Образцы" }
    OrderedStratagems.Push(id)
	
	; Separator
    id := "separator_6"
    Stratagems[id] := []
    StratagemNames[id] := { English: " ", Русский: " " }
    OrderedStratagems.Push(id)
	
	; === CATEGORY: Driver Assistant ===
    id := "category_driver_assistant"
    Stratagems[id] := []
    StratagemNames[id] := { English: "--- Driver Assistant ---", Русский: "--- Ассистент Вождения ---" }
    OrderedStratagems.Push(id)

    id := "Gear_first"
    Stratagems[id] := ["GearSwitch1"]
    StratagemNames[id] := { English: "First Gear", Русский: "Первая передача" }
    OrderedStratagems.Push(id)

    id := "Gear_reverse"
    Stratagems[id] := ["GearSwitch2"]
    StratagemNames[id] := { English: "Reverse Gear", Русский: "Реверсивная передача" }
    OrderedStratagems.Push(id)
}

RemoveToolTip:
ToolTip
return

GuiClose:
ExitApp