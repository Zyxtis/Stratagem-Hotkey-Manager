# Stratagem-Hotkey-Manager
Simpe AutoHotkey script for Helldivers 2, offering extensive customization and a wide range of functions.

This AutoHotkey script is built for Helldivers 2, allowing you to customize and optimize Stratagem activation for your unique playstyle. It streamlines complex key combinations, enabling you to assign any Stratagem to a single hotkey on your keyboard or mouse.

    Lite Version Release Notes
    A lite version of the script has been added, featuring a minimalist approach while retaining core functionality.
    The lite version includes only two tabs and minimal customization options.
    Default values are set to match the in-game standards.
    The dropdown list for keys allows you to select a pre-defined button. The very top option, [Hotkey], indicates that the input field will be used instead.
    The script can be suspended/resumed at any time by pressing the Insert key.
    Feel free to translate it into your language.


Key Features:

    Input Mode Selection: Choose between Arrow keys or WASD for stratagem input.
    Input Type Selection: Matches in-game input methods.
    Customizable Activation Key: Select or set your preferred key to activate the stratagem input menu (default is Left Control).
    Customizable Timings: Fine-tune delay settings for precise control.
    User-Friendly Interface (GUI): A simple graphical interface allows you to easily add, modify, and remove your keybinds.
    Quick Weapon Function Switching: Instantly switch weapon functions with dedicated hotkeys.
    Quick Inventory Item Drop: Quickly drop inventory items using assigned hotkeys.
    Two Languages: English and Russian.
    Settings Persistence: All your binds and settings are automatically saved to an INI file, so you don't have to reconfigure everything each time you launch the script.


Usage Instructions:

    1. Download and install AutoHotkey 1.1.37.02, then run the StratagemCaller.ahk script. Alternatively, you can use the compiled version: StratagemCaller.exe
    2. Select your Stratagem input layout: Arrows or WASD("Settings" tab). The script defaults to Arrows, while the game typically uses WASD
    3. Configure the Stratagem Menu Key: Choose your key from the dropdown menu (Left Ctrl is the default). Alternatively, you can assign any other key. To do this, select "Input" from the dropdown and press your desired key in the input field. Click "Apply Key" to save your changes("Settings" tab)
    4. Set a Hotkey for the Macro: In the "Set macro hotkey" field, enter the desired key to bind your Stratagem call to. Choose a suitable option for additional buttons from the dropdown list. Don't forget to switch to "Input" when you add other keys using the input field
    5. Select a Stratagem: Choose the desired Stratagem from the list
    6. Add the Binding: Click the "Add Binding" button
    7. Delete a Binding (if needed): To remove a binding, select it with a left mouse click in the list and press "Delete Selected"
    8. Utilize Profile Functionality (if needed)
    9. Press your assigned key binding to execute the Stratagem macro


Important Note:

The script is highly sensitive to keyboard layouts. To avoid instability, always use the same layout (English is recommended), especially when launching the script, as well as when modifying and saving hotkeys. When applying new settings, you'll see a confirmation window showing the assigned hotkeys; please carefully check that the key layout is displayed correctly to prevent future errors and ensure stable script operation. If you encounter errors after using multiple layouts, you may need to manually edit the .ini file to remove incorrect entries, or simply delete the .ini file entirely (be aware this will reset all saved settings and binds), then restart the script.

If Steam is running as administrator, the script itself should also be run as administrator. This is essential for the script to interact correctly with the game window.

It's recommended to use the Arrows input layout. Change your Stratagem input layout in the game's controls to arrow keys. Using WASD can hinder your mobility, as you won't be able to call Stratagems while moving.

Default Hotkeys:

    Insert — Suspends the script. Pressing Insert again will resume its operation.
    End — Close the script.
    Home — Shows/hides the floating window displaying the current profile and its binds. (To move this window, click on the top section where profile name is displayed).
    Page Up / Page Down — Switches profiles forward / backward

You can change these hotkeys by setting your own. To disable an unwanted function, simply clear its corresponding key field using Backspace and click "Apply".

Checkbox Function Description:

This adds the * operator to your hotkey. This means it will trigger regardless of whether other modifier keys (like Ctrl, Alt, Shift, or Win) are held down at the same time.

Only use this option for keybinds where you need them to activate independently of active modifiers. For example, if you're sprinting (holding Shift) and want to simultaneously call a stratagem or drop your backpack using a hotkey.
Be careful: if you already use modifier-key combinations (e.g., Ctrl+Q) for your keybinds, activating this option for the plain 'Q' key can lead to overlapping triggers or unexpected behavior.

Weapon Assistant

Designed for use with weapons like: Epoch, RS-422 "Railgun", ARC-3 "Arc Thrower", PLAS-101 "Purifier", and PLAS-15 "Scythe".

There are four available modes: one for Epoch, two for the RS-422 "Railgun" and one universal for other weapons:

    Purifier/Arc Thrower: Charges for 1 second, then releases. Hold the left mouse button for continuous fire.
    Railgun (Normal): Charges for 0.5 seconds, then fires and reloads. This mode is designed for safe Railgun use.
    Railgun (Unsafe): Charges for 2.9 seconds, then fires and reloads. Use this mode for the unsafe Railgun mode.
    Epoch: Charges for 2.5 second, then releases.


The script performs a predefined action cycle by automatically triggering a left mouse click, based on the selected mode. A single press of the hotkey runs one cycle, while holding the hotkey will continuously repeat the action until release. After launch, it remains inactive until you enable it with its hotkey.

It's not recommended to activate the Weapon Assistant while the AutoHotkey GUI window is active. Clicking inside the window might cause a "stuck click" which can be resolved by pressing Esc or opening Task Manager. While this could be fixed in the script, it would negatively impact overall stability.

Driver Assistant
This feature introduces automatic gear shifting to enhance vehicle responsiveness and handling. Press W to shift to first gear and S to shift to reverse. Additionally, the script automatically deactivates this functionality when you press E (the vehicle exit key).

Weapon Functions, Inventory Manager
Switch between weapon functions and manage your inventory with a single key press.

Super Important Note: If you're using the compiled .exe file, Windows Security (Windows Defender) might flag it and send it for review. This could interfere with the script's operation. Please be aware of this and proceed at your own discretion.

AHK Designations:

    MButton - Middle mouse button / scroll wheel (click)
    XButton1 - Fourth mouse button (usually the "Back" button in a browser)
    XButton2 - Fifth mouse button (usually the "Forward" button in a browser)
    WheelUp - Scroll mouse wheel up
    WheelDown - Scroll mouse wheel down
    ^ - Ctrl key
    ! - Alt key
    + - Shift key
    * - "Any modifier key" operator. Makes the hotkey universal. The hotkey will trigger even if other modifiers (Ctrl, Alt, Shift, Win) are being held down at that moment.
    ~ - "Pass-through" operator. Causes the hotkey to execute its action without blocking the original keypress from reaching the application.
