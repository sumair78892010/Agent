import '../models/agent_action.dart';
import '../models/chat_message.dart';
import 'app_launcher_service.dart';
import 'contacts_service.dart';
import 'communication_service.dart';
import 'alarm_service.dart';
import 'system_control_service.dart';
import 'shizuku_service.dart';
import 'screen_automation_service.dart';
import 'verification_service.dart';
import 'task_executor.dart';
import 'ai_service.dart';
import 'file_operation_service.dart';
import 'web_operation_service.dart';

class ActionHandler {
  final AppLauncherService _appLauncher = AppLauncherService();
  final ContactsService _contacts = ContactsService();
  final CommunicationService _communication = CommunicationService();
  final AlarmService _alarm = AlarmService();
  final SystemControlService _systemControl = SystemControlService();
  final ShizukuService _shizuku = ShizukuService();
  final ScreenAutomationService _screenAutomation = ScreenAutomationService();
  final VerificationService _verification = VerificationService();
  final FileOperationService _fileOps = FileOperationService();
  final WebOperationService _webOps = WebOperationService();

  ShizukuService get shizuku => _shizuku;
  ScreenAutomationService get screenAutomation => _screenAutomation;
  FileOperationService get fileOps => _fileOps;
  WebOperationService get webOps => _webOps;

  TaskExecutor? _currentExecutor;

  Future<AgentActionResult> execute(
    AgentAction action, {
    AiService? aiService,
    void Function(String)? onProgress,
  }) async {
    try {
      String result;
      bool success = false;

      switch (action.action) {
        case 'open_app':
          final appName = action.params['app_name'] as String? ?? '';
          final target = await _appLauncher.resolveApp(appName);
          if (target == null) {
            return AgentActionResult(
              actionType: action.action,
              success: false,
              details:
                  'Could not find app "$appName". Try being more specific.',
            );
          }
          result = await _appLauncher.openPackage(target.packageName);
          final isOpen = await _verification.verifyAppOpened(
            target.packageName,
            target.name,
          );
          success = isOpen;
          if (!success) {
            result =
                'Failed to open ${target.name} (the app did not become foreground)';
          } else {
            result = 'Opened ${target.name}';
          }
          break;

        case 'launch_package':
          final packageName = action.params['package_name'] as String? ?? '';
          result = await _appLauncher.openPackage(packageName);
          final isOpen = await _verification.verifyAppOpened(packageName, null);
          success = isOpen;
          if (!success) {
            result =
                'Failed to launch $packageName (package did not become foreground)';
          }
          break;

        case 'make_call':
          result = await _communication.makeCall(
            contactName: action.params['contact_name'] as String?,
            phoneNumber: action.params['phone_number'] as String?,
          );
          success = !result.startsWith('Error');
          break;

        case 'send_sms':
          result = await _communication.sendSms(
            contactName: action.params['contact_name'] as String?,
            phoneNumber: action.params['phone_number'] as String?,
            message: action.params['message'] as String? ?? '',
          );
          success = !result.startsWith('Error');
          break;

        case 'search_contact':
          result = await _contacts.searchAndFormat(
            action.params['query'] as String? ?? '',
          );
          success = !result.startsWith('Error');
          break;

        case 'set_alarm':
          result = await _alarm.setAlarm(
            hour: (action.params['hour'] as num?)?.toInt() ?? 0,
            minute: (action.params['minute'] as num?)?.toInt() ?? 0,
            label: action.params['label'] as String?,
          );
          success = !result.startsWith('Error');
          break;

        case 'set_timer':
          result = await _alarm.setTimer(
            seconds: (action.params['seconds'] as num?)?.toInt() ?? 60,
            label: action.params['label'] as String?,
          );
          success = !result.startsWith('Error');
          break;

        case 'set_volume':
          final volumeLevel = (action.params['level'] as num?)?.toInt() ?? 50;
          result = await _systemControl.setVolume(volumeLevel);
          success = !result.startsWith('Error');
          if (success) {
            success = await _verification.verifyVolumeSet(volumeLevel);
            if (!success) {
              result =
                  'Volume command sent but could not confirm the level changed';
            }
          }
          break;

        case 'set_brightness':
          final brightnessLevel =
              (action.params['level'] as num?)?.toInt() ?? 50;
          result = await _systemControl.setBrightness(brightnessLevel);
          success = !result.startsWith('Error');
          if (success) {
            success = await _verification.verifyBrightnessSet(brightnessLevel);
            if (!success) {
              result =
                  'Brightness command sent but could not confirm the level changed';
            }
          }
          break;

        case 'run_adb_command':
          result = await _shizuku.runCommand(
            action.params['command'] as String? ?? '',
          );
          success = !result.startsWith('Error');
          break;

        case 'send_email':
          result = await _communication.sendEmail(
            to: action.params['to'] as String? ?? '',
            subject: action.params['subject'] as String?,
            body: action.params['body'] as String?,
          );
          success = !result.startsWith('Error');
          break;

        case 'read_screen':
          result = await _screenAutomation.getScreenDescription();
          success = !result.contains('Could not read screen');
          break;

        case 'click_element':
          final text = action.params['text'] as String? ?? '';
          final beforeScreen = await _screenAutomation.getScreenDescription();
          final clickSuccess = await _screenAutomation.clickByText(text);
          final verified = clickSuccess
              ? await _verification.verifyElementClicked(
                  text,
                  beforeScreen: beforeScreen,
                )
              : false;
          success = clickSuccess && verified;
          result = success
              ? 'Clicked "$text" and verified a screen-state change'
              : 'Could not verify click on "$text"';
          break;

        case 'type_on_screen':
          final text = action.params['text'] as String? ?? '';
          final hint = action.params['field_hint'] as String?;
          final beforeType = await _verification.captureScreenSnapshot();
          final typeSuccess = await _screenAutomation.typeText(
            text,
            fieldHint: hint,
          );
          final verified = await _verification.verifyTextTyped(
            text,
            fieldHint: hint,
            beforeScreen: beforeType,
          );
          success = typeSuccess && verified;
          result = success
              ? 'Typed "$text" and verified text appears on screen'
              : 'Could not type "$text" or text not found on screen';
          break;

        case 'scroll_screen':
          final beforeScreen = await _verification.captureScreenSnapshot();
          final direction = action.params['direction'] as String? ?? 'down';
          final scrollSuccess = await _screenAutomation.scroll(direction);
          String afterScreen = '';
          if (scrollSuccess) {
            await Future.delayed(const Duration(milliseconds: 300));
            afterScreen = await _verification.captureScreenSnapshot();
          }
          final verified = await _verification.verifyScroll(
            beforeScreen,
            afterScreen,
          );
          success = scrollSuccess && verified;
          result = success
              ? 'Scrolled $direction and verified content changed'
              : 'Could not verify scroll $direction';
          break;

        case 'press_back':
          final beforeBack = await _verification.captureScreenSnapshot();
          final backSuccess = await _screenAutomation.pressBack();
          if (backSuccess) {
            await Future.delayed(const Duration(milliseconds: 300));
            final afterBack = await _verification.captureScreenSnapshot();
            // Verify screen actually changed after pressing back.
            success =
                beforeBack.trim() != afterBack.trim() &&
                !afterBack.contains('Could not read screen');
          } else {
            success = false;
          }
          result = success
              ? 'Pressed back and verified navigation'
              : 'Could not verify back navigation';
          break;

        case 'execute_task':
          final goal = action.params['goal'] as String? ?? action.response;
          if (aiService == null) {
            result = 'AI service not available for task execution.';
            success = false;
            break;
          }
          _currentExecutor = TaskExecutor(
            aiService: aiService,
            screenService: _screenAutomation,
            appLauncher: _appLauncher,
            shizukuService: _shizuku,
            onProgress: onProgress,
          );
          result = await _currentExecutor!.executeTask(goal);
          success = _isSuccessfulTaskResult(result);
          _currentExecutor = null;
          break;

        case 'read_file':
          result = await _fileOps.readTextFile(
            action.params['path'] as String? ?? '',
          );
          success = !result.startsWith('Error');
          break;

        case 'write_file':
          final writePath = action.params['path'] as String? ?? '';
          final writeContent = action.params['content'] as String? ?? '';
          final writeOk = await _fileOps.writeTextFile(writePath, writeContent);
          if (writeOk) {
            success = await _verification.verifyFileExists(writePath);
            if (success && writeContent.isNotEmpty) {
              success =
                  await _verification.verifyFileContent(
                    writePath,
                    expectedContent: writeContent,
                  );
            }
            result = success
                ? 'File written and verified at $writePath'
                : 'File write command succeeded but verification failed';
          } else {
            success = false;
            result = 'Could not write file';
          }
          break;

        case 'list_directory':
          final files = await _fileOps.listDirectory(
            action.params['path'] as String? ?? '',
          );
          result =
              'Found ${files.length} items:\n${files.map((f) => '${f.isDirectory ? "[DIR]" : "[FILE]"} ${f.name}').join("\n")}';
          success = true;
          break;

        case 'create_directory':
          final dirPath = action.params['path'] as String? ?? '';
          final dirOk = await _fileOps.createDirectory(dirPath);
          if (dirOk) {
            success = await _verification.verifyFileExists(dirPath);
            result = success
                ? 'Directory created and verified at $dirPath'
                : 'Directory creation command succeeded but path not found';
          } else {
            success = false;
            result = 'Could not create directory';
          }
          break;

        case 'copy_file':
          final copySrc = action.params['source'] as String? ?? '';
          final copyDst = action.params['destination'] as String? ?? '';
          final copyOk = await _fileOps.copyFile(copySrc, copyDst);
          if (copyOk) {
            success = await _verification.verifyFileCopied(copySrc, copyDst);
            result = success
                ? 'File copied and verified ($copySrc → $copyDst)'
                : 'Copy command succeeded but verification failed';
          } else {
            success = false;
            result = 'Could not copy file';
          }
          break;

        case 'move_file':
          final moveSrc = action.params['source'] as String? ?? '';
          final moveDst = action.params['destination'] as String? ?? '';
          final moveOk = await _fileOps.moveFile(moveSrc, moveDst);
          if (moveOk) {
            success = await _verification.verifyFileMoved(moveSrc, moveDst);
            result = success
                ? 'File moved and verified ($moveSrc → $moveDst)'
                : 'Move command succeeded but verification failed';
          } else {
            success = false;
            result = 'Could not move file';
          }
          break;

        case 'delete_file':
          final delPath = action.params['path'] as String? ?? '';
          final delOk = await _fileOps.deleteFile(delPath);
          if (delOk) {
            success = await _verification.verifyFileGone(delPath);
            result = success
                ? 'File deleted and verified at $delPath'
                : 'Delete command succeeded but file still exists';
          } else {
            success = false;
            result = 'Could not delete file';
          }
          break;

        case 'search_files':
          final searchResults = await _fileOps.searchFiles(
            action.params['directory'] as String? ?? '',
            action.params['query'] as String? ?? '',
          );
          result =
              'Found ${searchResults.length} files:\n${searchResults.map((f) => f.name).join("\n")}';
          success = true;
          break;

        case 'search':
          final engine = action.params['engine'] as String? ?? 'google';
          final searchQuery = action.params['query'] as String? ?? '';
          success = await _webOps.search(searchQuery, engine: engine);
          if (success) {
            success = await _verification.verifySearchResults(searchQuery);
            if (!success) {
              result = 'Search launched but could not confirm results loaded';
            } else {
              result = 'Searched for "$searchQuery" and verified results';
            }
          } else {
            result = 'Could not open search';
          }
          break;

        case 'open_url':
          final url = action.params['url'] as String? ?? '';
          success = await _webOps.openUrl(url);
          if (success) {
            // Wait briefly for the browser/page to load, then verify
            // something meaningful is on screen.
            await Future.delayed(const Duration(seconds: 2));
            final pageContent = await _verification.captureScreenSnapshot();
            success =
                !pageContent.contains('Could not read screen') &&
                pageContent.trim().length > 30;
            result = success
                ? 'Opened "$url" and verified page loaded'
                : 'URL was launched but page content could not be confirmed';
          } else {
            result = 'Could not open URL';
          }
          break;

        case 'get_page_content':
          result = await _webOps.getPageContent();
          success = result.isNotEmpty;
          break;

        case 'navigate_back':
          success = await _webOps.goBack();
          result = success ? 'Navigated back' : 'Could not go back';
          break;

        default:
          result = 'Unsupported action: ${action.action}';
          success = false;
          break;
      }

      return AgentActionResult(
        actionType: action.action,
        success: success,
        details: result,
      );
    } catch (e) {
      return AgentActionResult(
        actionType: action.action,
        success: false,
        details: 'Exception: ${e.toString()}',
      );
    }
  }

  bool _isSuccessfulTaskResult(String result) {
    final normalized = result.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    const failureMarkers = [
      'error',
      'could not complete',
      'could not understand',
      'task cancelled',
      'reached maximum steps',
      'task stuck',
      'failed',
    ];
    return !failureMarkers.any(normalized.contains);
  }

  void cancelTask() {
    _currentExecutor?.cancel();
  }
}
