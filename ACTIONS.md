# Agent Cypher - Supported Actions

This document lists all actions that Agent Cypher can execute. Each action includes its parameters, return value, and any special notes.

## App Management Actions

### `open_app`
Open an installed application

**Parameters:**
- `app_name` (String, required): Name or package name of the app to open
- `wait_time` (int, optional): Milliseconds to wait before verifying (default: 1000)

**Returns:** Success message with app name

**Example:**
```dart
AgentAction(
  action: 'open_app',
  params: {'app_name': 'YouTube'},
)
```

### `close_app`
Close a running application

**Parameters:**
- `app_name` (String, required): Name of the app to close

**Returns:** Success message or error

### `list_apps`
List all installed applications

**Parameters:** None

**Returns:** List of installed app names and package names

## Communication Actions

### `make_call`
Initiate a phone call

**Parameters:**
- `phone_number` (String, required): Phone number to call

**Returns:** Success message

**Verification:** Real call initiated (verified by checking active call state)

### `send_sms`
Send a text message

**Parameters:**
- `phone_number` (String, required): Recipient phone number
- `message` (String, required): Message content

**Returns:** Success message

### `send_email`
Send an email (opens Gmail or email app)

**Parameters:**
- `recipient` (String, required): Email address
- `subject` (String, optional): Email subject
- `body` (String, optional): Email body

**Returns:** Success message

## Contact Management Actions

### `find_contact`
Search for a contact by name

**Parameters:**
- `name` (String, required): Contact name to search for

**Returns:** Contact details (name, phone, email)

### `add_contact`
Add a new contact

**Parameters:**
- `name` (String, required): Contact name
- `phone` (String, optional): Phone number
- `email` (String, optional): Email address

**Returns:** Success message

### `update_contact`
Update an existing contact

**Parameters:**
- `name` (String, required): Contact name
- `phone` (String, optional): New phone number
- `email` (String, optional): New email

**Returns:** Success message

### `delete_contact`
Delete a contact

**Parameters:**
- `name` (String, required): Contact name

**Returns:** Success message with confirmation

## Media Actions

### `play_music`
Play audio/music

**Parameters:**
- `song_name` (String, optional): Song or artist name

**Returns:** Success message

### `take_screenshot`
Capture current screen

**Parameters:** None

**Returns:** Path to saved screenshot

### `record_video`
Start recording video

**Parameters:**
- `duration` (int, optional): Duration in seconds

**Returns:** Path to recorded video

## System Control Actions

### `set_brightness`
Adjust screen brightness

**Parameters:**
- `level` (double, required): Brightness level (0.0 to 1.0)

**Returns:** Success message

### `set_volume`
Adjust system volume

**Parameters:**
- `level` (int, required): Volume level (0-15)
- `stream_type` (String, optional): notification, ring, music, voice

**Returns:** Success message

### `toggle_wifi`
Turn WiFi on or off

**Parameters:**
- `enabled` (bool, required): true to enable, false to disable

**Returns:** Success message (may require Shizuku)

### `toggle_bluetooth`
Turn Bluetooth on or off

**Parameters:**
- `enabled` (bool, required): true to enable, false to disable

**Returns:** Success message (may require Shizuku)

### `toggle_airplane_mode`
Turn airplane mode on or off

**Parameters:**
- `enabled` (bool, required): true to enable, false to disable

**Returns:** Success message (requires Shizuku)

### `set_alarm`
Set a new alarm

**Parameters:**
- `hour` (int, required): Hour (0-23)
- `minute` (int, required): Minute (0-59)
- `label` (String, optional): Alarm label
- `days` (List<String>, optional): Repeat days (e.g., ["Monday", "Friday"])

**Returns:** Success message

### `cancel_alarm`
Cancel an existing alarm

**Parameters:**
- `label` (String, required): Alarm label to cancel

**Returns:** Success message

### `set_reminder`
Set a reminder

**Parameters:**
- `title` (String, required): Reminder title
- `time` (String, required): Time as HH:MM format
- `note` (String, optional): Additional note

**Returns:** Success message

## Screen Automation Actions

### `read_screen`
Get current screen content and layout

**Parameters:** None

**Returns:** Screen description with text, elements, layout

**Verification:** Screen read successfully

### `click_element`
Click on a UI element by text

**Parameters:**
- `text` (String, required): Text of element to click

**Returns:** Success message with element name

**Verification:** Real element clicked, screen changed

### `type_on_screen`
Type text into a focused field

**Parameters:**
- `text` (String, required): Text to type
- `field_hint` (String, optional): Field identifier/hint

**Returns:** Success message

**Verification:** Text actually appears on screen

### `scroll_screen`
Scroll the current screen

**Parameters:**
- `direction` (String, required): up, down, left, right

**Returns:** Success message

**Verification:** Screen position changed

### `press_back`
Press the back button

**Parameters:** None

**Returns:** Success message or error

### `press_home`
Press the home button

**Parameters:** None

**Returns:** Success message

## File Operations Actions

### `read_file`
Read text file contents

**Parameters:**
- `path` (String, required): File path

**Returns:** File contents as string

### `write_file`
Write or create a text file

**Parameters:**
- `path` (String, required): File path
- `content` (String, required): Content to write

**Returns:** Success message

### `list_directory`
List files in a directory

**Parameters:**
- `path` (String, required): Directory path

**Returns:** List of files with names and sizes

### `create_directory`
Create a new directory

**Parameters:**
- `path` (String, required): Directory path

**Returns:** Success message

### `copy_file`
Copy a file

**Parameters:**
- `source` (String, required): Source file path
- `destination` (String, required): Destination file path

**Returns:** Success message

### `move_file`
Move/rename a file

**Parameters:**
- `source` (String, required): Source file path
- `destination` (String, required): Destination file path

**Returns:** Success message

### `delete_file`
Delete a file

**Parameters:**
- `path` (String, required): File path

**Returns:** Success message (requires confirmation)

### `search_files`
Search for files by name

**Parameters:**
- `directory` (String, required): Directory to search in
- `query` (String, required): Search query/pattern

**Returns:** List of matching file paths

## Web Operations Actions

### `search`
Search using a search engine

**Parameters:**
- `query` (String, required): Search query
- `engine` (String, optional): google, bing, duckduckgo, youtube, wikipedia (default: google)

**Returns:** Success message

### `open_url`
Open a URL in browser

**Parameters:**
- `url` (String, required): URL to open

**Returns:** Success message

### `get_page_content`
Get current web page content

**Parameters:** None

**Returns:** Page text content

### `navigate_back`
Go back in browser history

**Parameters:** None

**Returns:** Success message

### `click_element`
Click on a web element

**Parameters:**
- `elementText` (String, required): Text of element to click

**Returns:** Success message

### `type_in_field`
Type into a web form field

**Parameters:**
- `text` (String, required): Text to type
- `fieldHint` (String, optional): Field identifier

**Returns:** Success message

### `submit_form`
Submit a web form

**Parameters:** None

**Returns:** Success message

## Task Execution Actions

### `execute_task`
Execute a multi-step task

**Parameters:**
- `goal` (String, required): High-level goal description
- `max_steps` (int, optional): Maximum steps (default: 5)

**Returns:** Task completion status and result

**Notes:** 
- Agent breaks down goal into steps
- Each step is verified
- Can be interrupted with "stop_task"
- Uses AI planning

### `stop_task`
Stop the currently running task

**Parameters:** None

**Returns:** Task cancellation confirmation

### `get_task_status`
Get status of current task

**Parameters:** None

**Returns:** Current step, progress percentage, actions taken

## Memory Actions

### `remember_preference`
Store a user preference

**Parameters:**
- `key` (String, required): Preference key
- `value` (String, required): Preference value

**Returns:** Success message

### `get_preferences`
Retrieve all stored preferences

**Parameters:** None

**Returns:** Dictionary of preferences

### `remember_fact`
Store a fact about the user

**Parameters:**
- `fact` (String, required): Fact to remember

**Returns:** Success message

### `get_facts`
Retrieve all stored facts

**Parameters:** None

**Returns:** List of facts

### `forget_fact`
Remove a stored fact

**Parameters:**
- `fact` (String, required): Fact to remove

**Returns:** Success message

## Special Actions

### `get_ai_context`
Get current AI context and state

**Parameters:** None

**Returns:** Current context information

### `clear_cache`
Clear agent cache and temporary data

**Parameters:** None

**Returns:** Success message

### `run_diagnostics`
Run system diagnostics

**Parameters:** None

**Returns:** List of diagnostic results with status

## Error Handling

All actions return with the following fields:
- `success` (bool): Whether the action succeeded
- `result` (String): Human-readable result message
- `details` (String): Additional details or error message

**Common Error Messages:**
- "Action not supported on this device"
- "Permission denied - requires [permission_name]"
- "Failed to execute action: [reason]"
- "Action timed out after 30 seconds"

## Retry Behavior

Actions that fail are automatically retried:
- Attempt 1: Immediate
- Attempt 2: After 500ms
- Attempt 3: After 2000ms

If all retries fail, an error is returned to the user.

## Verification

Critical actions verify their success by checking device state:
- **App launch**: Verifies app is in foreground
- **Click/type**: Verifies screen changed or text appeared
- **Settings changes**: Verifies new setting applied
- **File operations**: Verifies file exists or changed
- **Navigation**: Verifies page/screen loaded

This ensures actions actually executed, not just "didn't throw an error."
