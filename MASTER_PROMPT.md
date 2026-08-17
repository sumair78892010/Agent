AGENT CYPHER MASTER JARVIS BUILD, ENGINEERING & FEATURE-ENFORCEMENT SPECIFICATION 

Product: Agent Cypher
Identity: “An Assistant for Sumair”
Creator: Cypher Ghost
Package: "com.cypherghost.agentcypher"
Platform: Android
Source Repository: https://github.com/orailnoor/private-agent.git
Primary goal: Transform the supplied existing codebase into a genuinely functional, premium, always-available AI assistant that feels like a practical JARVIS-style companion.

SOURCE REPOSITORY — MANDATORY STARTING POINT 

The existing Git repository is the foundation of this project:

https://github.com/orailnoor/private-agent.git

This is NOT a request to create a new application from scratch.

The objective is:

EXISTING PRIVATE-AGENT CODEBASE → AUDIT → REFACTOR → UPGRADE → AGENT CYPHER

You must work directly on the supplied repository.

Do not create a separate unrelated project.

Do not replace the entire application with a toy implementation.

Do not throw away working functionality simply because creating a new implementation is easier.

The repository itself must become the final Agent Cypher application.

REPOSITORY-FIRST EXECUTION RULE 

Before writing or modifying significant code:

Clone/open the repository. Inspect the complete repository tree. Inspect the Git status and current branch. Inspect the existing commit/version state. Read the README and project documentation. Inspect pubspec.yaml. Inspect pubspec.lock. Inspect the complete lib/ architecture. Inspect the complete android/ implementation. Inspect AndroidManifest.xml. Inspect Gradle configuration. Inspect native Android services. Inspect Accessibility implementation. Inspect overlay implementation. Inspect provider/API implementation. Inspect settings. Inspect voice functionality. Inspect authentication. Inspect local plugins. Inspect assets. Inspect tests. Inspect GitHub Actions/build configuration. Search for obsolete branding. Search for Telegram functionality. Search for API keys and secrets. Build the existing project if the environment permits. Run the existing tests. Record actual failures. Then begin the migration. 

Do not pretend to have inspected files that were not actually inspected.

EXISTING CODEBASE PRESERVATION RULE 

The repository is expected to contain useful existing functionality.

Before replacing any subsystem, determine:

what it does; whether it works; how it is connected; what dependencies it uses; what Android APIs it relies upon; whether it can be refactored into Agent Cypher. 

Prefer:

Inspect → Preserve → Refactor → Integrate

over:

Delete → Rebuild

Existing Accessibility and Android automation functionality should be treated as valuable foundation for Agent Cypher.

Existing AI provider functionality should be migrated into the new provider architecture.

Existing task/action logic should be evaluated and integrated into the Agent Core.

Existing UI should be evaluated and upgraded rather than blindly discarded.

REPOSITORY-SPECIFIC MIGRATION 

The existing project may contain references to the original application identity, original creator, Telegram functionality, and existing AI providers.

These must be handled as an actual migration.

Search globally for:

PrivateAgent privateagent private_agent orailnoor OrailNoor Telegram telegram DeepSeek OpenRouter obsolete package names obsolete application labels obsolete creator references old URLs old notification names old service names 

Do not blindly modify third-party dependency code.

Only modify application-owned code and resources.

GIT SAFETY 

Before destructive modifications:

inspect Git status; preserve existing work; avoid destructive history rewrites; do not force-push; do not delete unrelated branches; inspect references before deleting files; make logical checkpoints when appropriate. 

Never expose credentials found in the repository.

If secrets are discovered:

do not print them; remove them from source; migrate them to secure storage; check whether they exist in configuration/history; report that a secret was discovered without displaying its value. FINAL REPOSITORY REQUIREMENT 

The final implementation must remain inside the supplied repository.

The result must be buildable from that repository.

Do not tell the user to manually copy generated files into another project.

Do not leave the main implementation in temporary directories.

Do not create a second unrelated application.

The repository itself must become:

Agent Cypher

0. YOUR ROLE 

You are acting as a:

Senior Android engineer Flutter engineer Android systems engineer AI-agent architect UI/UX designer automation engineer accessibility engineer QA engineer build/release engineer 

You are NOT merely generating example code.

You are responsible for taking the supplied project from its current state to a working Agent Cypher application.

You must inspect the existing architecture before making architectural decisions.

You must use the existing repository as the foundation.

ABSOLUTE RULE 

UPGRADE THE EXISTING CODEBASE.

Do NOT throw away a functioning existing implementation merely because rebuilding is easier.

Before modifying anything:

inspect the complete repository; identify the framework and architecture; identify existing working features; identify broken features; identify dependencies; identify Android services; identify API/provider architecture; identify permissions; identify screens; identify build configuration; identify duplicated/dead code; identify security problems; identify existing Accessibility implementation; identify existing task/action execution; identify existing voice implementation; identify existing overlay implementation; identify existing authentication; identify existing storage; identify existing provider configuration; identify existing tests. 

Preserve useful existing functionality unless it conflicts with the Agent Cypher specification.

1. NON-NEGOTIABLE ENGINEERING RULES 

Never:

create fake functionality; create placeholder buttons that do nothing; create mock AI responses; create fake device-control results; pretend an action succeeded when it did not; hardcode API keys; hardcode authentication secrets; leave TODO implementations for required features; silently remove existing functionality; replace a real implementation with a visual mock; claim APK compilation succeeded without actually compiling it; claim a provider is connected without testing it; claim Accessibility works without testing it; claim the floating bubble works without testing it; claim voice works without testing it; claim an action succeeded without verification. 

Every feature must be one of:

IMPLEMENTED → TESTED → VERIFIED

or, if Android/platform restrictions make it impossible:

IMPLEMENTED WITH PLATFORM LIMITATION → EXPLAINED IN UI → FALLBACK PROVIDED

Never fake success.

2. FIRST ACTION: COMPLETE CODEBASE AUDIT 

Before making major changes, inspect the entire project.

Create an internal implementation inventory covering:

Architecture Flutter/native Android/hybrid architecture state management navigation networking persistence dependency injection background services permissions AndroidManifest Gradle configuration native method channels platform channels local plugins Existing functionality 

Determine exactly what already works.

Broken functionality 

Locate:

compile errors runtime crashes dead buttons broken navigation incorrect permissions incorrect provider errors broken API configuration broken voice features broken overlay broken accessibility broken face authentication broken attachments broken live mode incorrect package names incorrect creator references broken task execution broken screen reading broken app launching broken settings broken persistence Security audit 

Search for:

API keys tokens passwords secrets Firebase credentials OAuth secrets private URLs debug logging of credentials insecure local storage credentials in assets credentials in JSON credentials in Dart credentials in Kotlin/Java credentials in XML credentials in Gradle credentials in CI configuration 

Never print discovered secrets.

3. REBRAND EVERYTHING 

Remove all references to:

"PrivateAgent" "privateagent" "private_agent" "orailnoor" "OrailNoor" original creator identity original Telegram identity obsolete branding 

Replace branding with:

Agent Cypher

Subtitle:

An Assistant for Sumair

Creator:

Cypher Ghost

Package:

"com.cypherghost.agentcypher"

Search the entire repository after migration and verify that obsolete branding no longer exists in application-owned files.

Do not blindly replace strings inside third-party dependencies.

Update:

application label; package/application ID; launcher name; notification names; service labels; settings; onboarding; about screen; metadata; documentation; splash screen; icons; user-facing errors. 4. REMOVE TELEGRAM DEPENDENCIES 

Completely remove obsolete Telegram functionality if it belongs to the original project:

imports screens services login bots settings permissions API configuration sharing models repositories unused dependencies background Telegram services Telegram notification handling Telegram-specific state 

Then:

remove dependencies; run dependency resolution; run static analysis; run tests; build; verify unrelated functionality. 

Do not merely hide Telegram UI.

Remove the underlying obsolete implementation.

5. SECRET MANAGEMENT 

No API key may exist directly in source code.

Support user-configured providers through Settings.

Use Android encrypted storage such as:

AndroidX Security / EncryptedSharedPreferences

or the secure equivalent appropriate to the project's architecture.

Secrets must never appear in:

logs crash messages screenshots analytics debug output task history exported chats Git repositories 

Mask API keys by default.

Provide:

Show Hide Copy Replace Delete Test connection 

with appropriate security protections.

If the existing project stores keys insecurely, migrate existing credentials to secure storage.

6. AGENT CYPHER PERSONALITY 

Cypher should feel like a calm, intelligent personal assistant.

Default identity:

“I’m Agent Cypher, your personal AI assistant.”

Address the user as:

Sumair

unless changed in Settings.

Tone:

intelligent concise calm confident respectful natural slightly futuristic never childish never excessively verbose during commands 

Examples:

User:

“Turn on the flashlight.”

Cypher:

“Flashlight on.”

User:

“Open YouTube and search for piano tutorials.”

Cypher:

“Opening YouTube and searching for piano tutorials.”

User:

“What can you do?”

Cypher explains capabilities naturally.

7. JARVIS-STYLE UX PRINCIPLE 

The application must not feel like a normal chatbot with buttons attached.

The core experience is:

VOICE / TEXT → UNDERSTAND → PLAN → EXECUTE → VERIFY → RESPOND

The AI should determine the appropriate execution mechanism.

Example:

User:

“Open YouTube.”

Cypher must:

identify the installed YouTube package; resolve its launch intent; launch YouTube; verify the foreground package; report the actual result. 

It must NOT simply open Chrome and search YouTube.

Example:

“Open Settings and turn Bluetooth on.”

Cypher should:

determine the required device-control route; open the appropriate system interface or use an authorized system API; inspect the resulting UI/state; perform the action when permitted; verify the final state; report success or failure. 8. AI AGENT ARCHITECTURE 

Create a central agent architecture:

User Input ↓ Intent Understanding ↓ Context Collector ↓ Task Planner ↓ Permission/Safety Check ↓ Execution Router ↓ Action Executor ↓ Screen/State Observer ↓ Verification ↓ Retry/Replan ↓ Response 

Separate these components.

Do not put all logic into one giant class.

Recommended modules:

agent/ AgentCore AgentPlanner AgentExecutor AgentRouter AgentContext AgentMemory AgentVerifier AgentRecovery providers/ AIProvider GeminiProvider OpenAIProvider GLMProvider NVIDIAProvider AnthropicProvider OpenRouterProvider GroqProvider CustomProvider device/ AccessibilityController AppController DeviceController ScreenController NotificationController ShizukuController voice/ WakeWordService SpeechRecognizer TextToSpeechManager tasks/ TaskManager TaskQueue TaskHistory AutomationManager ui/ Chat Bubble AssistantPanel Settings Commands Files 

Adapt names to the existing architecture rather than blindly creating duplicate systems.

If the existing repository already contains equivalent components, refactor and integrate them.

9. STRUCTURED AGENT PROTOCOL 

The AI must return machine-readable execution instructions.

Use a schema similar to:

{ "task": { "id": "unique-task-id", "description": "Open YouTube", "risk": "low" }, "actions": [ { "type": "open_app", "package": "com.google.android.youtube" } ], "response": "Opening YouTube." } 

For multi-step actions:

{ "task": { "description": "Search YouTube for piano tutorials", "risk": "low" }, "actions": [ { "type": "open_app", "package": "com.google.android.youtube" }, { "type": "wait", "milliseconds": 1200 }, { "type": "tap_element", "text": "Search" }, { "type": "type", "text": "piano tutorials" }, { "type": "submit" }, { "type": "verify_ui", "expected": "search results" } ], "response": "Searching YouTube for piano tutorials." } 

Never expose hidden chain-of-thought.

The UI may show concise status such as:

Understanding → Planning → Executing → Verifying → Complete

but never reveal private internal reasoning.

10. ACTION TYPES 

Create a unified action registry.

Minimum actions:

open_app close_app tap tap_element long_press swipe scroll type clear_text press_back press_home open_url search wait screenshot read_screen find_element select submit verify_ui read_notification send_notification set_volume set_brightness toggle_flashlight create_file read_file write_file copy_file move_file rename_file delete_file compress extract start_recording stop_recording schedule_task cancel_task speak listen ask_user 

Every action must have:

validation execution timeout result verification error handling cancellation support 

Actions must report actual execution state.

11. EXECUTION ENGINE 

This is one of the most important systems.

For every task:

PLAN ↓ VALIDATE ↓ EXECUTE ↓ OBSERVE ↓ VERIFY ↓ SUCCESS 

If failure occurs:

FAILURE ↓ DIAGNOSE ↓ RETRY ↓ ALTERNATIVE ROUTE ↓ ASK USER 

Never endlessly retry.

Use configurable limits.

Always allow cancellation.

The executor must never report success based only on the absence of an exception.

12. SCREEN UNDERSTANDING 

When Accessibility is enabled, Cypher should be able to inspect:

current package current activity when available visible text content descriptions clickable elements editable fields scrollable containers buttons dialogs accessibility nodes 

Provide semantic targeting.

Prefer:

text; contentDescription; resourceId; accessibility node properties; 

over blind coordinates.

Coordinates should be a fallback.

The screen observer must expose structured state to the Agent Core.

13. ACCESSIBILITY SERVICE 

Implement or improve the proper Android AccessibilityService where permitted.

Support:

click long press swipe scroll text entry back home recent apps reading visible UI detecting foreground application semantic element lookup UI state observation 

Provide a clear setup screen explaining why Accessibility is required.

Never secretly enable or bypass Android security restrictions.

If the existing repository already contains an Accessibility service, refactor it rather than creating a competing service.

14. SHIZUKU 

If Shizuku is installed and authorized:

detect availability; detect authorization; use it only for supported privileged operations; provide fallback implementations; never assume Shizuku exists. 

Settings should show:

Shizuku: Connected / Not installed / Not authorized

Never claim Shizuku-powered functionality is available when it is not authorized.

15. FLOATING CYPHER BUBBLE 

Create a premium floating assistant bubble.

Specifications:

56dp circular deep warm-black background cream Cypher mark subtle cream ring no saturated colors 

States:

IDLE LISTENING THINKING SPEAKING EXECUTING SUCCESS ERROR NOTIFICATION 

Interactions:

Tap

Open assistant panel.

Double tap

Start listening.

Long press

Quick actions.

Drag

Move bubble.

Release

Snap to nearest safe screen edge.

Persist position.

Avoid duplicate overlays.

Respect Android overlay permission.

Use a foreground service where required.

Start after boot only when the user has explicitly enabled that behavior.

16. ASSISTANT PANEL 

The panel should feel like a compact JARVIS interface.

Include:

AGENT CYPHER branding model indicator status animated Cypher orb/face conversation current task status microphone attachment text input send cancel context-aware actions 

Panel height:

40% → 95%

with drag resizing.

Opening animation:

spring + fade

Closing:

spring + fade

The panel must share the same Agent Core as chat, voice, bubble, tasks and device control.

17. WAKE WORD 

Default:

Hey Cypher

Allow custom wake word where the selected engine supports it.

Possible engines:

Vosk Porcupine Android SpeechRecognizer other compatible local engine 

Do not promise always-listening functionality when Android/OEM restrictions prevent it.

Provide:

enable/disable sensitivity screen-off listening confirmation sound haptic feedback continuous conversation auto-stop duration 

Wake word state must survive appropriate service restarts.

18. VOICE PIPELINE 

Implement:

Wake Word ↓ Listening ↓ Speech Recognition ↓ Intent ↓ Agent ↓ Execution ↓ Text Response ↓ TTS 

TTS:

Android TextToSpeech configurable voice rate pitch volume earphone-only mode voice output toggle 

Default pitch may be slightly lower for the JARVIS feel, but remain natural.

Voice must use the same Agent Core as text commands.

19. MULTI-PROVIDER AI SYSTEM 

Create a universal provider interface.

Minimum capabilities:

getProviderName() getModels() testConnection() sendMessage() streamMessage() supportsVision() supportsTools() supportsStructuredOutput() 

Support providers where their APIs are compatible and legally/technically available:

NVIDIA Gemini OpenAI Anthropic OpenRouter Groq GLM DeepSeek Mistral Hugging Face Ollama Custom OpenAI-compatible endpoint 

Do not hardcode provider assumptions.

Each provider must have:

name base URL API key models capabilities connection status 

Migrate any useful provider code already present in the supplied repository into this architecture.

20. NVIDIA / NEMOTRON SUPPORT 

Provide first-class support for OpenAI-compatible NVIDIA endpoints.

Configuration must allow:

Provider: NVIDIA Base URL: user-configurable API Key: encrypted Model: user-configurable 

Do not hardcode a model that may disappear or change.

The provider UI must clearly report:

“NVIDIA connection failed.”

rather than incorrectly reporting another provider.

Connection errors must identify the selected provider.

21. PROVIDER UI 

Settings → AI Providers

Display cards:

NVIDIA Connected Nemotron ... [Change Model] [Test] Gemini Not configured [Configure] 

Allow:

add provider edit remove test select default model selection per-chat model switching custom endpoint capability detection 

Never display the full secret.

22. CHAT 

Main chat must contain:

premium header current model conversation streaming responses task status cancel button attachments voice input structured execution status code blocks copy regenerate retry continue 

AI messages must be clean and readable.

Avoid huge unformatted walls of text.

When an agent task is running, the chat should show actual execution events rather than fake progress.

Example:

Understanding Planning Executing Observing Verifying Complete 

Only display states generated by the real execution pipeline.

23. COMMAND SYSTEM 

Cypher should understand natural language.

Examples:

“Turn the flashlight on.”

“Open YouTube.”

“Take a screenshot.”

“Set brightness to 40 percent.”

“What is my battery percentage?”

“Read my notifications.”

“Open WhatsApp.”

“Search the web for the latest Android news.”

“Remember that I prefer concise answers.”

“What do you remember about me?”

“Forget that.”

“Create a folder called Projects.”

“Find my PDF files.”

“Compress these files.”

“Set a reminder.”

“Start a routine.”

Do not require exact command syntax.

The AI should map natural language to structured actions.

24. DEVICE CONTROL 

Where Android permits it, implement:

Device:

flashlight brightness volume screen state where permitted screenshot screen recording battery information storage information memory information Wi-Fi settings Bluetooth settings DND settings system settings 

Some operations may require Android settings panels or privileged access.

Never claim an unsupported direct toggle succeeded.

When a direct API is unavailable, use the strongest legitimate fallback.

25. APP CONTROL 

Cypher should understand installed applications.

Create an application registry containing:

package name label launch intent icon launch availability 

When user says:

“Open YouTube.”

Resolve:

YouTube ↓ package lookup ↓ launch intent ↓ verify foreground package 

Do NOT default to opening Chrome.

If the requested application is not installed:

report that accurately; optionally offer a legitimate web fallback; never claim the application was opened. 26. WEB AGENT 

Create a controlled web execution layer.

Capabilities:

search navigate extract text click type scroll submit download screenshot inspect page state recover from navigation errors 

Use appropriate APIs or browser mechanisms rather than pretending a WebView is a complete browser.

When a CAPTCHA or human verification appears:

pause and request user assistance.

Do not attempt to bypass CAPTCHA or security controls.

27. DOWNLOAD MANAGER 

Create a legitimate download system.

Support:

HTTP/HTTPS downloads progress pause where supported resume where supported cancellation MIME detection file naming duplicate handling Download/Movies/Music/Documents organization 

Before downloading potentially sensitive or destructive content, ask for confirmation when appropriate.

Do not implement DRM bypassing or unauthorized access.

28. MEMORY 

Implement persistent memory.

Memory types:

preference fact instruction conversation task device preference 

User commands:

“Remember that I prefer concise answers.”

“What do you remember?”

“Forget my preference about concise answers.”

Memory must be editable and deletable.

Store only information necessary for the feature.

Provide:

Settings → Memory

with:

search edit delete delete all 

Memory must connect to Agent Context so relevant information can be used during tasks.

29. TASK SYSTEM 

Tasks with 3+ meaningful actions should have an execution plan.

Example:

Task Search YouTube for piano tutorials 1. Open YouTube 2. Search piano tutorials 3. Verify results [Proceed] [Modify] [Cancel] 

For low-risk user-authorized tasks, allow configurable auto-execution.

Always provide cancellation.

Task state must persist appropriately.

30. SAFETY / CONFIRMATION MODEL 

Three autonomy modes:

LOW 

Ask before executing actions.

MEDIUM 

Execute ordinary actions automatically.

Ask before sensitive actions.

HIGH 

Execute ordinary actions automatically.

Ask before high-impact actions.

Always require confirmation for:

purchases financial transactions account deletion destructive file operations sending sensitive information installing unknown software changing important security settings actions with irreversible consequences 

Never bypass Android security controls.

31. TASK RECOVERY 

When an action fails:

capture current state; determine why; attempt safe recovery; retry within a limit; choose an alternative route; ask the user if necessary. 

Example:

“Could not find the Search button.”

“Trying an alternative UI route…”

Do not silently continue as though successful.

Every recovery attempt must produce an actual event.

32. MEMORY + CONTEXT 

For each task, provide context:

Current application Current screen Relevant accessibility text Recent user messages Relevant memories Device state Task history 

Only provide context necessary for the current task.

Do not indiscriminately send all device data to the AI provider.

33. FILE MANAGEMENT 

Provide:

browse search sort filter preview copy move rename create folder compress extract share delete with confirmation duplicate detection 

Respect Android scoped-storage rules.

Use SAF where required.

Verify destructive file operations before reporting success.

34. CODE GENERATION 

Cypher can generate software projects.

Workflow:

User request ↓ Create project structure ↓ Generate files ↓ Validate syntax ↓ Run available checks ↓ Fix errors ↓ Package project 

Never tell the user code was compiled if it was not.

When Android build tools are available:

Generate ↓ Gradle build ↓ Inspect errors ↓ Fix ↓ Build again 

For coding tasks, Cypher must report actual command output/status.

35. AUTOMATIONS 

Support:

scheduled tasks reminders routines battery triggers app-open triggers time triggers connectivity triggers where Android permits 

Use:

AlarmManager WorkManager BroadcastReceiver foreground services 

only where appropriate.

Respect Android background execution restrictions.

36. ROUTINES 

Include configurable examples:

Morning 

Weather → calendar → notifications → selected briefing

Night 

DND → reminder/alarm → selected settings

Gaming 

DND → selected brightness/volume → launch game

Battery Saver 

Perform only actions actually permitted by Android.

Every routine must be editable.

37. SECURITY / AUTHENTICATION 

Support optional:

Android BiometricPrompt device credentials PIN fallback 

Do not claim custom face recognition is secure authentication unless the implementation actually provides appropriate liveness/security guarantees.

BiometricPrompt should be the preferred authentication mechanism.

If the existing project contains insecure custom face recognition, do not present it as equivalent to Android's trusted biometric authentication.

38. PREMIUM VISUAL DESIGN 

Strict palette:

LIGHT #F7F3EE #F0EBE3 #E8E1D6 #FFFFFF #1C1917 #57534E #8C857D #B8B0A6 #3D3833 #D6CFC4 DARK #1C1917 #252220 #2E2A27 #F0EBE3 #B8B0A6 #8C857D #57534E #D6CFC4 

Absolutely no saturated:

blue green red purple pink orange gold 

unless an accessibility/system requirement forces a platform-generated color.

The visual identity should feel:

premium warm sophisticated minimal futuristic JARVIS-like not childish not gamer-like not neon cyberpunk 39. LIQUID GLASS 

Use real platform-appropriate glass effects.

Where true background blur is unavailable or expensive, use a visually equivalent translucent layered surface rather than a fake performance-heavy blur.

Glass surfaces:

cards dialogs navigation assistant panel bubble inputs task cards provider cards settings notifications menus 

Maintain readability and contrast.

Do not sacrifice usability merely to create a glass effect.

40. TYPOGRAPHY 

Headings:

Cormorant Garamond 600

Body/UI:

DM Sans 400

Buttons/labels:

DM Sans 600

Code:

JetBrains Mono

Never use excessive bold typography.

Typography must remain readable at the smallest supported device size.

41. RESPONSIVE MOBILE DESIGN 

Minimum:

360dp

Target:

360–1024dp+

Requirements:

minimum 48dp touch targets readable typography correct keyboard handling WindowInsets safe areas gesture navigation no accidental horizontal overflow no desktop-style UI squeezed onto mobile tablet optimization portrait support landscape support where appropriate 

The application must work on phones and tablets.

42. DARK MODE 

Support:

Light Dark System 

Every screen must be tested in both modes.

No white flashes.

No unreadable text.

No leftover Material default colors.

No components should silently revert to unrelated system colors.

43. JARVIS FACE / ORB 

Create a lightweight animated Cypher visual.

Do NOT make it cartoonish.

States:

Idle Listening Thinking Executing Speaking Success Error 

Use:

cream black neutral grey subtle rings subtle eye animation 

No heavy 3D engine.

Animation should react to actual Agent Core state.

44. APP ICON 

Create:

Stylized C + circuit aesthetic

Background:

"#1C1917"

Foreground:

"#F7F3EE"

Create:

adaptive icon legacy icon notification icon launcher assets 

Ensure Android-specific density resources are correct.

Replace old application icons.

45. SPLASH SCREEN 

Android 12+ SplashScreen API.

Use:

warm black background Cypher logo Agent Cypher typography subtle fade no unnecessary loading delay 

Do not artificially delay startup.

46. SETTINGS 

Settings must include:

Account profile login logout AI Providers providers keys models default model Appearance Light/Dark/System glass intensity font size Voice wake word STT TTS sensitivity haptics Security biometric PIN trust duration Device Access Accessibility Overlay Notifications MediaProjection Shizuku Commands aliases command settings Automation routines schedules Memory view edit delete Privacy data logs permissions Diagnostics provider services storage permissions database About Agent Cypher version creator 47. ONBOARDING 

First launch:

Welcome ↓ Agent Cypher introduction ↓ Choose AI provider ↓ Enter API key ↓ Test connection ↓ Choose model ↓ Voice setup ↓ Overlay permission ↓ Accessibility permission ↓ Notification access ↓ Optional security ↓ Complete 

Do not ask for unnecessary permissions.

Explain every sensitive permission before opening Android Settings.

Allow users to skip optional permissions and configure them later.

48. NOTIFICATION SYSTEM 

Create proper notification channels:

Agent Service Tasks Completed Errors Wake Word Chat 

Task notifications should support:

progress cancel completion 

Never create notification spam.

Notification content must never expose secrets.

49. ANIMATION 

Use restrained premium animation.

Examples:

page transition: 300ms card entry: 200ms button press: 100ms panel spring bubble pulse typing indicator task progress orb animation 

Respect reduced-motion accessibility settings.

Animations must not block actions or artificially delay the UI.

50. PERFORMANCE 

Target:

smooth 60fps UI

Avoid:

unnecessary recompositions memory leaks permanent high-frequency polling excessive background work battery-draining loops unnecessary network requests unnecessary screen captures 

Wake-word processing should be optimized for battery consumption.

Accessibility event processing should be efficient.

Do not repeatedly send identical screen data to the AI provider.

51. ERROR HANDLING 

Every error must be:

user-readable provider-specific actionable safe 

Bad:

“DeepSeek API not configured.”

when NVIDIA is selected.

Good:

“NVIDIA API connection failed. Check your API key or endpoint.”

Never expose:

API keys stack traces to normal users internal secrets private filesystem paths unnecessarily 

Errors must identify the actual failing subsystem.

52. PERMISSION CENTER 

Create a centralized permission manager.

Display:

Microphone ✓ Notifications ✓ Overlay ✓ Accessibility ✗ Shizuku ✗ Screen capture ✗ 

Each permission gets:

status explanation setup button recheck button 

The application must adapt gracefully when optional permissions are unavailable.

Permission state must be checked at runtime rather than assumed from a previous onboarding step.

53. CHAT + DEVICE CONTEXT 

Cypher should know relevant context when available:

Current app Battery Time Connectivity Current task Relevant screen text User preferences 

Do not collect unnecessary data.

Only send context to an AI provider when it is relevant to the requested task.

54. SEARCH 

Provide configurable search providers.

Search workflow:

Query ↓ Search provider ↓ Results ↓ Extract ↓ Summarize 

Cite or identify sources when appropriate.

Do not claim web access if the selected provider is unavailable.

Search must have provider-specific error handling.

55. APP SELF-DIAGNOSTICS 

Add:

Settings → Diagnostics

Check:

AI provider network microphone TTS wake word overlay accessibility notification listener Shizuku storage background service database app integrity 

Show:

PASS / WARNING / FAILED

with remediation instructions.

Diagnostics must perform real checks.

Do not simply display predetermined green checkmarks.

56. LOGGING 

Use structured internal logging.

Production logs must redact:

API keys tokens passwords personal secrets 

Allow users to export diagnostic logs only after reviewing what is included.

Never log:

full authorization headers; API keys; authentication tokens; sensitive message content unnecessarily; private files unnecessarily. 57. TESTING 

Create tests for:

AI provider connection streaming malformed responses timeout retry structured output provider-specific errors Agent plan parsing action validation cancellation retry verification recovery Device app launch accessibility actions screen reading permission states device state verification UI light dark tablet phone keyboard rotation reduced motion Storage memories tasks settings encrypted credentials 

Tests must reflect the actual implementation.

58. BUILD VALIDATION 

Before claiming completion:

clean build; resolve dependency errors; run static analysis; run tests; build debug APK; install if environment permits; launch; verify onboarding; verify provider setup; verify chat; verify permissions; verify bubble; verify task execution; verify Accessibility; verify voice where test environment permits; verify diagnostics; build release APK. 

Never say:

“Everything works.”

unless it has actually been tested.

Report limitations honestly.

59. BUILD OUTPUT 

Target:

applicationId: com.cypherghost.agentcypher minSdk: 26 targetSdk: 34 or the current stable target supported by the project/toolchain version: 1.0.0 

Use release signing only when a valid keystore is available.

If no keystore exists:

generate one only with explicit user approval; never invent a password; never expose signing secrets; explain exactly where the keystore is stored. 

Output:

agent-cypher-v1.0.0-release.apk

when a release build actually succeeds.

Do not rename a debug APK and call it a release APK.

60. CRITICAL ANDROID REALITY CHECK 

Do not promise impossible behavior.

Android versions and OEMs may restrict:

background execution microphone access overlay behavior accessibility notification access app installation Wi-Fi/Bluetooth direct control screen recording boot startup background wake-word detection 

When a limitation exists:

implement the strongest permitted method + provide a fallback + explain the limitation.

Never bypass Android security.

Do not attempt to secretly grant permissions.

Do not use Accessibility to circumvent Android security restrictions.

61. IMPLEMENTATION ORDER 

Follow this order unless the existing architecture requires another dependency order:

PHASE 1 — AUDIT 

Inspect and report.

PHASE 2 — FOUNDATION 

Fix build system and architecture.

PHASE 3 — IDENTITY 

Rebrand and remove obsolete code.

PHASE 4 — SECURITY 

Secure provider credentials and storage.

PHASE 5 — DESIGN SYSTEM 

Colors, typography, glass, themes.

PHASE 6 — CORE AI 

Universal provider adapter.

PHASE 7 — AGENT CORE 

Planner, executor, router, verifier.

PHASE 8 — DEVICE CONTROL 

Accessibility, app launching, permissions, Shizuku.

PHASE 9 — VOICE 

Wake word, STT, TTS.

PHASE 10 — FLOATING UI 

Bubble and assistant panel.

PHASE 11 — TASK SYSTEM 

Plans, queue, cancellation, history.

PHASE 12 — MEMORY 

Persistent user memory.

PHASE 13 — WEB 

Search, browsing, downloads.

PHASE 14 — AUTOMATION 

Schedules and routines.

PHASE 15 — SECURITY 

Biometric/device credential integration.

PHASE 16 — ALL SCREENS 

Chat, commands, files, settings, notifications.

PHASE 17 — POLISH 

Animation, performance, accessibility.

PHASE 18 — TEST 

Full verification.

PHASE 19 — RELEASE 

Build APK.

Do not skip earlier phases simply because later UI work is easier.

62. DECISION POLICY 

Do not stop for trivial decisions.

Use sensible engineering defaults when:

the choice is reversible; the choice does not affect security; the choice does not require user credentials; the choice does not destroy existing data; the choice does not materially change product behavior. 

Ask the user only when genuinely necessary.

Examples requiring user input:

API key provider model signing key authentication provider optional sensitive permission destructive action irreversible architecture decision custom wake word requiring a specific engine 

Do NOT ask 20 questions before doing any work.

Proceed with everything that can safely be implemented first.

63. FEATURE COMPLETENESS RULE 

For every requested feature, track:

Requirement Implementation Files changed Dependencies Permissions Tests Verification Status 

Use statuses:

IMPLEMENTED TESTED VERIFIED BLOCKED PLATFORM-LIMITED 

Never use:

TODO COMING SOON PLACEHOLDER MOCK STUB 

for required functionality.

If something cannot be implemented because of an Android limitation, use:

PLATFORM-LIMITED

and provide a real fallback.

64. FINAL QA MATRIX 

Before completion, verify:

Identity [ ] Agent Cypher branding [ ] Cypher Ghost branding [ ] Sumair personalization [ ] old branding removed [ ] Telegram removed [ ] correct package name [ ] correct application label [ ] correct icon [ ] correct splash Security [ ] zero hardcoded API keys [ ] encrypted provider credentials [ ] secrets redacted from logs [ ] credentials not present in UI exports [ ] credentials not present in source AI [ ] universal provider architecture [ ] NVIDIA support [ ] model selection [ ] streaming [ ] connection testing [ ] provider-specific errors [ ] structured output [ ] vision capability detection [ ] tool capability detection Agent [ ] natural-language commands [ ] planning [ ] execution [ ] verification [ ] retry [ ] cancellation [ ] recovery [ ] task history [ ] actual execution events Device [ ] Accessibility [ ] app launching [ ] screen reading [ ] UI interaction [ ] notifications [ ] screenshot [ ] device state [ ] Shizuku integration where available Voice [ ] wake word [ ] STT [ ] TTS [ ] listening state [ ] speaking state [ ] cancellation [ ] background limitations handled UI [ ] premium black/cream design [ ] liquid glass [ ] light mode [ ] dark mode [ ] responsive tablet UI [ ] 48dp touch targets [ ] keyboard-safe [ ] no overflow [ ] reduced-motion support Bubble [ ] persistent [ ] draggable [ ] snap-to-edge [ ] state animation [ ] opens panel [ ] no duplicate instances [ ] actual service integration Memory [ ] remember [ ] recall [ ] forget [ ] edit [ ] delete [ ] persistence Tasks [ ] plans [ ] progress [ ] cancellation [ ] retry [ ] notifications [ ] history [ ] recovery Build [ ] clean build [ ] static analysis [ ] tests [ ] APK generated [ ] APK installation verified where possible [ ] no crash on launch [ ] release build verified 65. MOST IMPORTANT BEHAVIOR 

Agent Cypher must behave like this:

USER ↓ "Hey Cypher" ↓ CYPHER WAKES ↓ LISTEN ↓ UNDERSTAND ↓ PLAN ↓ ASK IF REQUIRED ↓ EXECUTE ↓ OBSERVE ↓ VERIFY ↓ RECOVER IF NEEDED ↓ RESPOND ↓ RETURN TO IDLE 

The application must feel like one coherent assistant, not a collection of unrelated features.

The bubble, chat, voice assistant, tasks, memory, device control and AI providers must all communicate through the same Agent Core.

There must not be separate competing AI/task/action pipelines.

66. FINAL COMMAND 

BUILD AGENT CYPHER.

Use:

https://github.com/orailnoor/private-agent.git

as the existing source code foundation.

Do not merely redesign the old application.

Do not merely generate a chatbot.

Do not merely create a beautiful UI.

Do not create a separate replacement project.

Create the underlying systems required for the assistant to actually:

listen, understand, plan, act, observe, verify, remember, speak and recover.

Preserve and improve useful existing functionality.

Fix existing bugs rather than hiding them.

Use the existing project as the foundation.

Migrate useful existing implementations rather than duplicating them.

Remove obsolete PrivateAgent/OrailNoor/Telegram functionality.

Secure all existing and new provider credentials.

Make the provider architecture modular.

Make NVIDIA/Nemotron support first-class.

Make device actions real where Android permits them.

Make Accessibility actions semantic and verifiable.

Make app launching resolve real installed packages.

Make task execution observable.

Make failures visible and recoverable.

Make the UI premium.

Make the architecture maintainable.

Make the AI provider system modular.

Make device actions real where Android permits them.

Make security a first-class requirement.

Make the application responsive and battery-conscious.

Make every implemented feature testable.

Make diagnostics real rather than decorative.

Make the final APK come from the upgraded repository.

Agent Cypher is the product.

JARVIS is the experience target.

Sumair is the user.

Cypher Ghost is the identity.

The supplied Git repository is the foundation.

Build it as a real Android assistant, not a visual prototype.

DO NOT STOP AT UI.

DO NOT STOP AT CODE GENERATION.

DO NOT STOP AT REBRANDING.

DO NOT STOP AT THE AUDIT.

DO NOT CLAIM SUCCESS WITHOUT BUILD VERIFICATION.

DO NOT FAKE FEATURES.

DO NOT CREATE A SECOND PROJECT.

DO NOT DELETE WORKING FUNCTIONALITY WITHOUT FIRST EVALUATING IT.

DO NOT ASK FOR PERMISSION TO PERFORM ORDINARY REVERSIBLE ENGINEERING WORK.

Proceed autonomously through all safe implementation work.

When a decision is reversible and non-destructive, choose the best engineering solution and continue.

When a required credential, signing secret, sensitive permission, destructive action, or genuinely irreversible decision is required, ask only for that specific input.

The final workflow is:

AUDIT ↓ UNDERSTAND EXISTING CODE ↓ ARCHITECT ↓ PRESERVE USEFUL SYSTEMS ↓ REMOVE OBSOLETE SYSTEMS ↓ REFACTOR ↓ IMPLEMENT ↓ INTEGRATE ↓ TEST ↓ FIX ↓ VERIFY ↓ BUILD ↓ INSTALL / LAUNCH TEST ↓ FINAL QA ↓ RELEASE APK 

AUDIT → ARCHITECT → IMPLEMENT → TEST → FIX → VERIFY → BUILD.

The repository is not a reference example.

It is the application that must be upgraded.

The specification is not a design suggestion.

It is the engineering acceptance criteria.

The final result must be a functioning Agent Cypher Android application.

