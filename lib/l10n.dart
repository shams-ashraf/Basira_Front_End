import 'package:shared_preferences/shared_preferences.dart';

/// Centralized localization helper for Basera app.
/// Supports 'en' (English) and 'ar' (Egyptian Arabic).
class L10n {
  L10n._();
  static String _lang = 'en';

  static String get currentLanguage => _lang;
  static bool get isArabic => _lang == 'ar';

  /// Call once at startup or when language changes.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _lang = prefs.getString('language') ??
        (prefs.getString('voice_language')?.startsWith('ar') == true
            ? 'ar'
            : 'en');
  }

  static void setLanguage(String lang) {
    _lang = lang;
  }

  static String tr(String key) {
    final map = isArabic ? _ar : _en;
    return map[key] ?? _en[key] ?? key;
  }

  // ─── English strings ───
  static const Map<String, String> _en = {
    // ── General ──
    'app_name': 'Basera',
    'save': 'Save',
    'cancel': 'Cancel',
    'done': 'Done',
    'retry': 'Retry',
    'error': 'Error',
    'success': 'Success',
    'loading': 'Loading...',
    'no_data': 'No data available',

    // ── Splash ──
    'splash_title': 'BASIRA (بصيرة)',
    'splash_subtitle': 'Smart AI Vision for Visually Impaired',

    // ── Setup ──
    'setup_title': 'Server Setup',
    'setup_heading': 'Configure Servers',
    'setup_desc': 'Enter the URLs or IP addresses (including ports) for the backend and AI servers.',
    'setup_backend_label': 'Backend Server URL (with Port)',
    'setup_ai_label': 'AI Server URL (with Port)',
    'setup_save_continue': 'Save & Continue',

    // ── Login ──
    'login_welcome': 'Welcome Back',
    'login_subtitle': 'Login to access your Basira platform',
    'login_email': 'Email Address',
    'login_password': 'Password',
    'login_button': 'Login',
    'login_no_account': "Don't have an account?",
    'login_signup_link': 'Sign Up',
    'login_fill_fields': 'Please fill in all fields.',
    'login_failed': 'Login failed.',

    // ── Signup ──
    'signup_title': 'Create Account',
    'signup_subtitle': 'Sign up as a parent or a child user',
    'signup_email': 'Email Address',
    'signup_email_helper': 'Use a valid email like name@example.com',
    'signup_password': 'Password',
    'signup_password_helper': '8+ chars, upper, lower, number, special char',
    'signup_parent_chip': 'Parent Dashboard',
    'signup_child_chip': 'Child Home',
    'signup_password_rules': 'Password rules: 8+ chars, uppercase, lowercase, number, special character.',
    'signup_button': 'Sign Up',
    'signup_success': 'Account created successfully! Please login.',
    'signup_failed': 'Signup failed. Please try again.',
    'email_required': 'Email is required.',
    'email_invalid': 'Enter a valid email like name@example.com.',
    'password_required': 'Password is required.',
    'password_min': 'Use at least 8 characters.',
    'password_upper': 'Add at least one uppercase letter.',
    'password_lower': 'Add at least one lowercase letter.',
    'password_digit': 'Add at least one number.',
    'password_special': 'Add at least one special character.',
    'password_max': 'Keep it at 72 characters or fewer.',

    // ── Select Role ──
    'role_basera': 'BASERA',
    'role_choose': 'Choose your role to begin',
    'role_parent': 'Parent',
    'role_parent_sub': 'Monitor & receive alerts',
    'role_child': 'Child',
    'role_child_sub': 'Smart voice assistant',
    'role_camera': 'Camera AI',
    'role_camera_sub': 'Dual-mode real-time ESP32-CAM monitoring',

    // ── Parent Dashboard ──
    'parent_welcome': 'Welcome 👋',
    'parent_monitor': 'Monitor your child',
    'parent_linked_child': 'Linked Child',
    'parent_unknown_child': 'Unknown Child',
    'parent_connected': 'Connected',
    'parent_child_safe': 'Child is safe',
    'parent_last_updated': 'Last updated: Now',
    'parent_no_danger': 'No danger detected',
    'parent_recent_alerts': 'Recent Alerts',
    'parent_no_alerts': 'No recent alerts.',
    'parent_link_device': 'Scan Child QR',
    'parent_camera_ai': 'Camera AI',
    'parent_alerts': 'Alerts',
    'parent_unknown': 'Unknown',
    'parent_persons': 'Persons',

    // ── Child Voice ──
    'voice_basera_ai': 'BASERA AI',
    'voice_alert_parents': 'Alert parents',
    'voice_object': 'OBJECT',
    'voice_scene': 'SCENE',
    'voice_listening': 'Listening...',
    'voice_hold_speak': 'Hold to Speak',
    'voice_alert_sent': 'Alert sent to parents.',
    'voice_alert_failed': 'Failed to send alert.',
    'voice_opening_object': 'Opening Object Detection.',
    'voice_opening_scene': 'Opening Scene Description.',
    'voice_ready': 'Hello, I am Basera assistant. What is your name? Press the glasses button to begin.',
    'voice_safety_ready': 'Safety mode is now active.',

    // ── Child QR ──
    'qr_connect_child': 'Connect Child',
    'qr_show_parent': 'Show this to Parent',
    'qr_config': 'Configuration (Technical)',
    'qr_server_ip': 'Server IP (e.g. 192.168.1.5:3000)',
    'qr_esp_ip': 'ESP32 pairing info',

    // ── Child Profile ──
    'profile_title': 'Child Profile 👶',
    'profile_name': 'Name',
    'profile_age': 'Age',
    'profile_school': 'School',
    'profile_save': '💾 SAVE CHANGES',
    'profile_edit': '✏️ EDIT PROFILE',
    'profile_signout': 'Sign Out',
    'profile_ai_lab': 'AI Lab',

    // ── Parent Scanner ──
    'scanner_title': 'Scan Child QR',
    'scanner_instruction': "Center the Child's QR code in the frame",
    'scanner_linked': 'Child linked successfully!',
    'scanner_invalid': 'Invalid QR code.',

    // ── Settings ──
    'settings_title': 'Settings ⚙️',
    'settings_language': 'Language',
    'settings_english': 'English',
    'settings_arabic': 'العربية المصرية',
    'settings_arabic_sub': 'صوت ونص عربي',
    'settings_save_lang': 'Save Language',
    'settings_lang_saved': '✅ Language saved!',
    'settings_logs': 'System Logs',
    'settings_logs_desc': 'View backend events, warnings, and errors.',
    'settings_open_logs': 'Open Logs',
    'settings_esp32': 'Camera',
    'settings_camera_ip': 'Camera IP Address',
    'settings_camera_ip_hint': 'e.g. 192.168.1.10',
    'settings_save_ip': 'Save IP Address',
    'settings_ip_saved': '✅ IP saved successfully!',

    // ── Persons ──
    'persons_title': 'Persons 👥',
    'persons_add': '➕ Add Person',
    'persons_none': 'No persons added yet',
    'persons_delete': '🗑 Delete',
    'persons_edit': '✏️ Edit',
    'persons_deleted': 'Person deleted successfully',
    'persons_offline': 'Offline mode: Showing local persons',
    'persons_delete_local': 'Deleted locally. Backend sync failed.',
    'persons_delete_failed': 'Delete failed',

    // ── Add Person ──
    'add_person_title': 'Register New Person',
    'add_person_name': 'Full Name',
    'add_person_capture': 'CAPTURE',
    'add_person_upload': 'UPLOAD',
    'add_person_register': 'REGISTER PERSON',
    'add_person_name_required': 'Please enter a full name first.',
    'add_person_image_required': 'Please add at least one image.',
    'add_person_success': 'registered successfully.',

    // ── Edit Person ──
    'edit_person_title': 'Edit Name',
    'edit_person_updated': 'Person updated successfully.',

    // ── Unknown ──
    'unknown_title': 'Unknown Persons',
    'unknown_none': 'No unknown persons found',
    'unknown_desc': 'Photos taken by the child appear here for the linked parent to review',
    'unknown_name_label': 'Enter person name',
    'unknown_save_known': 'Save as Known',
    'unknown_name_required': 'Please enter a name for this person.',

    // ── Alerts ──
    'alerts_title': 'Alerts',
    'alerts_none': 'No alerts yet',

    // ── System Logs ──
    'logs_title': 'System Logs',
    'logs_none': 'No system logs yet.',

    // ── AI Lab ──
    'ai_lab_title': 'AI Lab',
    'ai_lab_no_images': 'No AI evaluation images yet.',
    'ai_lab_capture_date': 'Capture Date',
    'ai_lab_capture_time': 'Capture Time',
    'ai_lab_object_detect': 'Object Detection',
    'ai_lab_object_live': 'Object Live',
    'ai_lab_scene_summary': 'Scene Summary',
    'ai_lab_scene_live': 'Scene Live',
    'ai_lab_choose_model': 'Choose Scene Model',

    // ── AI Lab Result ──
    'result_object_title': 'Object Detection Result',
    'result_scene_title': 'Scene Summary Result',
    'result_process_log': 'Process Log',
    'result_live_steps': 'Live Steps',
    'result_original': 'Original Image',
    'result_processed': 'Processed Image',
    'result_objects': 'Detected Objects',
    'result_person': 'Detected Person',
    'result_yes': 'Yes',
    'result_no': 'No',
    'result_none': 'None',
    'result_best_match': 'Best Match',
    'result_best_score': 'Best Similarity Score',
    'result_scores': 'Full Similarity Scores',
    'result_performance': 'Performance Metrics',

    // ── ESP32 Camera ──
    'esp_object_mode': 'Object Detection Mode',
    'esp_scene_mode': 'Scene Description Mode',
    'esp_live': 'Live Monitoring',
    'esp_offline': 'Stream Offline',
    'esp_stream_off': 'Stream is Off',
    'esp_stream_hint': 'Press ON to start real-time monitoring',
    'esp_connecting': 'Connecting to ESP32-CAM Stream...',
    'esp_error': 'Cannot reach ESP32-CAM\nCheck WiFi connection',
    'esp_reconnect': 'Reconnect',
    'esp_start_object': 'Start monitoring to see object detections',
    'esp_analyzing': 'Analyzing frame...',
    'esp_no_objects': 'No objects detected in view',
    'esp_start_scene': 'Start monitoring to see scene summary',
    'esp_generating': 'Generating scene summary...',
    'esp_no_summary': 'No summary generated yet',

    // ── AI Speech ──
    'ai_person_on': 'is on your',
    'ai_person_appears': 'and appears',
    'ai_person_unknown': 'I can see a person on your',
    'ai_careful': 'Careful, I can see a',
    'ai_on_your': 'on your',
    'ai_looks': 'and it looks',
    'ai_emergency': 'Emergency:',
    'ai_detected_on': 'detected on your',
    'ai_about': 'about',
    'ai_away': 'away.',
  };

  // ─── Modern Standard Arabic (MSA) strings ───
  static const Map<String, String> _ar = {
    // ── General ──
    'app_name': 'بصيرة',
    'save': 'حفظ',
    'cancel': 'إلغاء',
    'done': 'تم',
    'retry': 'حاول مرة أخرى',
    'error': 'خطأ',
    'success': 'تم بنجاح',
    'loading': 'جاري التحميل...',
    'no_data': 'لا توجد بيانات',

    // ── Splash ──
    'splash_title': 'بصيرة (BASIRA)',
    'splash_subtitle': 'مساعد ذكي بالذكاء الاصطناعي لذوي الإعاقة البصرية',

    // ── Setup ──
    'setup_title': 'إعداد السيرفر',
    'setup_heading': 'ظبط السيرفرات',
    'setup_desc': 'اكتب عناوين الـ IP أو الروابط (مع البورت) للسيرفر الأساسي وسيرفر الذكاء الاصطناعي.',
    'setup_backend_label': 'رابط سيرفر الباكيند (مع البورت)',
    'setup_ai_label': 'رابط سيرفر الذكاء الاصطناعي (مع البورت)',
    'setup_save_continue': 'حفظ واستمرار',

    // ── Login ──
    'login_welcome': 'أهلاً بك مجدداً',
    'login_subtitle': 'سجل دخولك لتتمكن من استخدام بصيرة',
    'login_email': 'البريد الإلكتروني',
    'login_password': 'كلمة المرور',
    'login_button': 'تسجيل الدخول',
    'login_no_account': 'ليس لديك حساب؟',
    'login_signup_link': 'سجل الآن',
    'login_fill_fields': 'يرجى ملء جميع الحقول.',
    'login_failed': 'فشل تسجيل الدخول.',

    // ── Signup ──
    'signup_title': 'إنشاء حساب',
    'signup_subtitle': 'سجل كولي أمر أو طفل',
    'signup_email': 'البريد الإلكتروني',
    'signup_email_helper': 'استخدم بريد صالح مثل name@example.com',
    'signup_password': 'كلمة المرور',
    'signup_password_helper': '٨+ أحرف، كبير، صغير، رقم، رمز خاص',
    'signup_parent_chip': 'لوحة الأهل',
    'signup_child_chip': 'واجهة الطفل',
    'signup_password_rules': 'قواعد كلمة المرور: ٨+ أحرف، حرف كبير، حرف صغير، رقم، رمز خاص.',
    'signup_button': 'إنشاء حساب',
    'signup_success': 'تم إنشاء الحساب بنجاح! يرجى تسجيل الدخول.',
    'signup_failed': 'فشل في إنشاء الحساب. حاول مرة أخرى.',
    'email_required': 'البريد الإلكتروني مطلوب.',
    'email_invalid': 'اكتب بريد صالح مثل name@example.com.',
    'password_required': 'كلمة المرور مطلوبة.',
    'password_min': 'يجب ألا تقل عن ٨ أحرف.',
    'password_upper': 'يجب أن تحتوي على حرف كبير واحد على الأقل.',
    'password_lower': 'يجب أن تحتوي على حرف صغير واحد على الأقل.',
    'password_digit': 'يجب أن تحتوي على رقم واحد على الأقل.',
    'password_special': 'يجب أن تحتوي على رمز خاص واحد على الأقل.',
    'password_max': 'يجب ألا تزيد عن ٧٢ حرفاً.',

    // ── Select Role ──
    'role_basera': 'بصيرة',
    'role_choose': 'اختر دورك لتبدأ',
    'role_parent': 'ولي الأمر',
    'role_parent_sub': 'مراقبة واستقبال التنبيهات',
    'role_child': 'الطفل',
    'role_child_sub': 'مساعد صوتي ذكي',
    'role_camera': 'كاميرا AI',
    'role_camera_sub': 'مراقبة مباشرة بكاميرا ESP32',

    // ── Parent Dashboard ──
    'parent_welcome': 'أهلاً بك 👋',
    'parent_monitor': 'راقب طفلك',
    'parent_linked_child': 'الطفل المربوط',
    'parent_unknown_child': 'طفل غير معروف',
    'parent_connected': 'متصل',
    'parent_child_safe': 'الطفل في أمان',
    'parent_last_updated': 'آخر تحديث: الآن',
    'parent_no_danger': 'لا يوجد خطر',
    'parent_recent_alerts': 'آخر التنبيهات',
    'parent_no_alerts': 'لا توجد تنبيهات حديثة.',
    'parent_link_device': 'مسح QR الطفل',
    'parent_camera_ai': 'كاميرا AI',
    'parent_alerts': 'التنبيهات',
    'parent_unknown': 'المجهولين',
    'parent_persons': 'الأشخاص',

    // ── Child Voice ──
    'voice_basera_ai': 'بصيرة AI',
    'voice_alert_parents': 'تنبيه الأهل',
    'voice_object': 'أشياء',
    'voice_scene': 'مشهد',
    'voice_listening': 'أستمع...',
    'voice_hold_speak': 'اضغط مع الاستمرار للتحدث',
    'voice_alert_sent': 'تم إرسال التنبيه للأهل.',
    'voice_alert_failed': 'فشل في إرسال التنبيه.',
    'voice_opening_object': 'حسناً، سأفتح التعرف على الأشياء.',
    'voice_opening_scene': 'حسناً، سأفتح وصف المشهد.',
    'voice_ready': 'مرحبًا، أنا مساعد بصيرة. ما اسمك؟ اضغط على زر النظارة للبدء.',
    'voice_safety_ready': 'وضع الأمان يعمل الآن.',

    // ── Child QR ──
    'qr_connect_child': 'ربط الطفل',
    'qr_show_parent': 'اعرض هذا لولي الأمر',
    'qr_config': 'إعدادات تقنية',
    'qr_server_ip': 'IP السيرفر (مثال: 192.168.1.5:3000)',
    'qr_esp_ip': 'معلومات الربط مع ESP32',

    // ── Child Profile ──
    'profile_title': 'بروفايل الطفل 👶',
    'profile_name': 'الاسم',
    'profile_age': 'السن',
    'profile_school': 'المدرسة',
    'profile_save': '💾 حفظ التعديلات',
    'profile_edit': '✏️ تعديل البروفايل',
    'profile_signout': 'تسجيل خروج',
    'profile_ai_lab': 'معمل الذكاء',

    // ── Parent Scanner ──
    'scanner_title': 'مسح QR الطفل',
    'scanner_instruction': 'ضع رمز الـ QR الخاص بالطفل في المنتصف',
    'scanner_linked': 'تم ربط الطفل بنجاح!',
    'scanner_invalid': 'رمز QR غير صالح.',

    // ── Settings ──
    'settings_title': 'الإعدادات ⚙️',
    'settings_language': 'اللغة',
    'settings_english': 'English',
    'settings_arabic': 'العربية الفصحى',
    'settings_arabic_sub': 'صوت ونص عربي فصحى',
    'settings_save_lang': 'حفظ اللغة',
    'settings_lang_saved': '✅ تم حفظ اللغة!',
    'settings_logs': 'سجلات النظام',
    'settings_logs_desc': 'عرض أحداث وتحذيرات وأخطاء النظام.',
    'settings_open_logs': 'فتح السجلات',
    'settings_esp32': 'الكاميرا',
    'settings_camera_ip': 'عنوان IP الكاميرا',
    'settings_camera_ip_hint': 'مثال: 192.168.1.10',
    'settings_save_ip': 'حفظ عنوان IP',
    'settings_ip_saved': '✅ تم حفظ الـ IP بنجاح!',

    // ── Persons ──
    'persons_title': 'الأشخاص 👥',
    'persons_add': '➕ إضافة شخص',
    'persons_none': 'لا يوجد أشخاص مضافين بعد',
    'persons_delete': '🗑 حذف',
    'persons_edit': '✏️ تعديل',
    'persons_deleted': 'تم حذف الشخص بنجاح',
    'persons_offline': 'وضع عدم الاتصال: يعرض الأشخاص المحليين',
    'persons_delete_local': 'تم الحذف محلياً. فشلت مزامنة الخادم.',
    'persons_delete_failed': 'فشل الحذف',

    // ── Add Person ──
    'add_person_title': 'تسجيل شخص جديد',
    'add_person_name': 'الاسم بالكامل',
    'add_person_capture': 'تصوير',
    'add_person_upload': 'رفع',
    'add_person_register': 'تسجيل الشخص',
    'add_person_name_required': 'يرجى كتابة الاسم الأول.',
    'add_person_image_required': 'يرجى إضافة صورة واحدة على الأقل.',
    'add_person_success': 'تم التسجيل بنجاح.',

    // ── Edit Person ──
    'edit_person_title': 'تعديل الاسم',
    'edit_person_updated': 'تم تعديل الشخص بنجاح.',

    // ── Unknown ──
    'unknown_title': 'المجهولين',
    'unknown_none': 'لا يوجد أشخاص مجهولين',
    'unknown_desc': 'الصور التي يلتقطها الطفل ستظهر هنا للمراجعة',
    'unknown_name_label': 'اكتب اسم الشخص',
    'unknown_save_known': 'حفظ كمعروف',
    'unknown_name_required': 'يرجى إدخال اسم الشخص.',

    // ── Alerts ──
    'alerts_title': 'التنبيهات',
    'alerts_none': 'لا توجد تنبيهات بعد',

    // ── System Logs ──
    'logs_title': 'سجلات النظام',
    'logs_none': 'لا توجد سجلات بعد.',

    // ── AI Lab ──
    'ai_lab_title': 'معمل الذكاء',
    'ai_lab_no_images': 'لا توجد صور تقييم ذكاء اصطناعي بعد.',
    'ai_lab_capture_date': 'تاريخ الالتقاط',
    'ai_lab_capture_time': 'وقت الالتقاط',
    'ai_lab_object_detect': 'كشف الأشياء',
    'ai_lab_object_live': 'أشياء مباشر',
    'ai_lab_scene_summary': 'وصف المشهد',
    'ai_lab_scene_live': 'مشهد مباشر',
    'ai_lab_choose_model': 'اختر نموذج المشهد',

    // ── AI Lab Result ──
    'result_object_title': 'نتيجة كشف الأشياء',
    'result_scene_title': 'نتيجة وصف المشهد',
    'result_process_log': 'سجل العمليات',
    'result_live_steps': 'الخطوات',
    'result_original': 'الصورة الأصلية',
    'result_processed': 'الصورة المعالجة',
    'result_objects': 'الأشياء المكتشفة',
    'result_person': 'شخص مكتشف',
    'result_yes': 'نعم',
    'result_no': 'لا',
    'result_none': 'لا يوجد',
    'result_best_match': 'أفضل تطابق',
    'result_best_score': 'أفضل نسبة تشابه',
    'result_scores': 'جميع نسب التشابه',
    'result_performance': 'مقاييس الأداء',

    // ── ESP32 Camera ──
    'esp_object_mode': 'وضع كشف الأشياء',
    'esp_scene_mode': 'وضع وصف المشهد',
    'esp_live': 'مراقبة مباشرة',
    'esp_offline': 'البث متوقف',
    'esp_stream_off': 'البث متوقف',
    'esp_stream_hint': 'اضغط ON لبدء المراقبة',
    'esp_connecting': 'جاري الاتصال بكاميرا ESP32...',
    'esp_error': 'لا يمكن الوصول لكاميرا ESP32\nراجع اتصال الواي فاي',
    'esp_reconnect': 'إعادة اتصال',
    'esp_start_object': 'ابدأ المراقبة لرؤية كشف الأشياء',
    'esp_analyzing': 'يتم تحليل الإطار...',
    'esp_no_objects': 'لا توجد أشياء مكتشفة في المشهد',
    'esp_start_scene': 'ابدأ المراقبة لرؤية وصف المشهد',
    'esp_generating': 'يتم إنشاء وصف المشهد...',
    'esp_no_summary': 'لا يوجد وصف بعد',

    // ── AI Speech (MSA) ──
    'ai_person_on': 'على',
    'ai_person_appears': 'ويبدو أنه',
    'ai_person_unknown': 'أرى شخصاً على',
    'ai_careful': 'انتبه، أرى',
    'ai_on_your': 'على',
    'ai_looks': 'والمسافة تقريباً',
    'ai_emergency': 'طوارئ!',
    'ai_detected_on': 'تم اكتشافه على',
    'ai_about': 'على مسافة',
    'ai_away': '.',
  };
}
