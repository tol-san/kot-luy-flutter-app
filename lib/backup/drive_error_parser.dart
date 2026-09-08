/// Maps connection-related errors into user-friendly Khmer messages.
/// Returns `null` if the user simply cancelled or backed out of the account chooser dialog.
String? parseDriveConnectError(Object error) {
  final str = error.toString().toLowerCase();
  if (str.contains('cancelled') ||
      str.contains('canceled') ||
      str.contains('no_account')) {
    // User dismissed account chooser dialog; no error banner needed
    return null;
  }
  if (str.contains('auth_denied') ||
      str.contains('authorization was not granted') ||
      str.contains('permission')) {
    return 'អ្នកមិនទាន់បានអនុញ្ញាតសិទ្ធិ Google Drive នៅឡើយទេ។ សូមព្យាយាមភ្ជាប់ម្ដងទៀត ហើយចុច «យល់ព្រម» ឬ «Allow»។';
  }
  if (str.contains('network') ||
      str.contains('socket') ||
      str.contains('timeout')) {
    return 'បញ្ហាតភ្ជាប់បណ្ដាញ សូមពិនិត្យមើល Wi-Fi ឬទិន្នន័យចល័ត (SIM)';
  }
  return 'ការភ្ជាប់មិនបានសម្រេចទេ សូមព្យាយាមម្ដងទៀត';
}

/// Maps Drive operations errors into user-friendly Khmer messages.
String parseDriveError(Object error) {
  final str = error.toString().toLowerCase();
  if (str.contains('network') ||
      str.contains('socket') ||
      str.contains('timeout')) {
    return 'បញ្ហាតភ្ជាប់បណ្ដាញ សូមពិនិត្យមើល Wi-Fi ឬទិន្នន័យចល័ត (SIM)';
  } else if (str.contains('auth_denied') ||
      str.contains('authorization was not granted') ||
      str.contains('permission')) {
    return 'មិនទាន់បានអនុញ្ញាតសិទ្ធិ Google Drive នៅឡើយទេ។ សូមភ្ជាប់ឡើងវិញ ហើយចុច «យល់ព្រម» ឬ «Allow»។';
  } else if (str.contains('reconnect') ||
      str.contains('unauthenticated') ||
      str.contains('auth_failed')) {
    return 'សូមភ្ជាប់គណនី Google ឡើងវិញ';
  } else if (str.contains('quota') || str.contains('storage')) {
    return 'ទំហំផ្ទុកលើ Google Drive របស់អ្នកបានពេញ';
  } else if (str.contains('too_large')) {
    return 'ឯកសារបម្រុងទុកមានទំហំធំលើសកំណត់';
  } else if (str.contains('integrity') || str.contains('invalid')) {
    return 'ឯកសារបម្រុងទុកមិនត្រឹមត្រូវ ឬខូចខាត';
  }
  return 'មិនអាចដំណើរការបានទេ សូមព្យាយាមម្ដងទៀត';
}
