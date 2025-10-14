import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ms.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ms')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Onboarding App'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @manageYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Manage Your Account'**
  String get manageYourAccount;

  /// No description provided for @devicePermission.
  ///
  /// In en, this message translates to:
  /// **'Device Permission'**
  String get devicePermission;

  /// No description provided for @languageAndTranslations.
  ///
  /// In en, this message translates to:
  /// **'Language and Translations'**
  String get languageAndTranslations;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @bahasaMelayu.
  ///
  /// In en, this message translates to:
  /// **'Bahasa Melayu'**
  String get bahasaMelayu;

  /// No description provided for @languageChangeNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Changing the language will affect all text in the application.'**
  String get languageChangeNote;

  /// No description provided for @languageChangedToEnglish.
  ///
  /// In en, this message translates to:
  /// **'Language changed to English'**
  String get languageChangedToEnglish;

  /// No description provided for @languageChangedToMalay.
  ///
  /// In en, this message translates to:
  /// **'Bahasa ditukar kepada Bahasa Melayu'**
  String get languageChangedToMalay;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong!'**
  String get somethingWentWrong;

  /// No description provided for @quickaction.
  ///
  /// In en, this message translates to:
  /// **'Quick Action'**
  String get quickaction;

  /// No description provided for @hello.
  ///
  /// In en, this message translates to:
  /// **'Hello,'**
  String get hello;

  /// No description provided for @mydocument.
  ///
  /// In en, this message translates to:
  /// **'My\nDocument'**
  String get mydocument;

  /// No description provided for @meettheteam.
  ///
  /// In en, this message translates to:
  /// **'Meet\nThe Team'**
  String get meettheteam;

  /// No description provided for @buddychat.
  ///
  /// In en, this message translates to:
  /// **'Buddy Chat'**
  String get buddychat;

  /// No description provided for @taskmanager.
  ///
  /// In en, this message translates to:
  /// **'Task Manager'**
  String get taskmanager;

  /// No description provided for @facilities.
  ///
  /// In en, this message translates to:
  /// **'Facilities'**
  String get facilities;

  /// No description provided for @learninghub.
  ///
  /// In en, this message translates to:
  /// **'Learning Hub'**
  String get learninghub;

  /// No description provided for @myjourney.
  ///
  /// In en, this message translates to:
  /// **'My\nJourney'**
  String get myjourney;

  /// No description provided for @news.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get news;

  /// No description provided for @scanqr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get scanqr;

  /// No description provided for @myqr.
  ///
  /// In en, this message translates to:
  /// **'My QR'**
  String get myqr;

  /// No description provided for @workinformation.
  ///
  /// In en, this message translates to:
  /// **'Work Information'**
  String get workinformation;

  /// No description provided for @position.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get position;

  /// No description provided for @workplace.
  ///
  /// In en, this message translates to:
  /// **'Workplace'**
  String get workplace;

  /// No description provided for @scanthisQRcodeapptoaddmeasacontactinapp.
  ///
  /// In en, this message translates to:
  /// **'Scan this QR code (app) to add me as a contact in-app'**
  String get scanthisQRcodeapptoaddmeasacontactinapp;

  /// No description provided for @thisQRcontainsavCardphonecamerasGoogleLenscanofferAddcontact.
  ///
  /// In en, this message translates to:
  /// **'This QR contains a vCard — phone cameras/Google Lens can offer (Add contact)'**
  String get thisQRcontainsavCardphonecamerasGoogleLenscanofferAddcontact;

  /// No description provided for @usevCardQRphonecameras.
  ///
  /// In en, this message translates to:
  /// **'Use vCard QR(Phone Camera)'**
  String get usevCardQRphonecameras;

  /// No description provided for @sortbyNameAZ.
  ///
  /// In en, this message translates to:
  /// **'Sort Name (A-Z)'**
  String get sortbyNameAZ;

  /// No description provided for @createNewFolder.
  ///
  /// In en, this message translates to:
  /// **'Create New Folder'**
  String get createNewFolder;

  /// No description provided for @addNewFile.
  ///
  /// In en, this message translates to:
  /// **'Add New File'**
  String get addNewFile;

  /// No description provided for @organizationChart.
  ///
  /// In en, this message translates to:
  /// **'Organization Chart'**
  String get organizationChart;

  /// No description provided for @departmentStructure.
  ///
  /// In en, this message translates to:
  /// **'Department Structure'**
  String get departmentStructure;

  /// No description provided for @departmentDirectory.
  ///
  /// In en, this message translates to:
  /// **'Department Directory'**
  String get departmentDirectory;

  /// No description provided for @searchNow.
  ///
  /// In en, this message translates to:
  /// **'Search Now...'**
  String get searchNow;

  /// No description provided for @searchnameorposition.
  ///
  /// In en, this message translates to:
  /// **'Seacrh name or position...'**
  String get searchnameorposition;

  /// No description provided for @userProfileDetail.
  ///
  /// In en, this message translates to:
  /// **'User Profile Detail'**
  String get userProfileDetail;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @phoneno.
  ///
  /// In en, this message translates to:
  /// **'Phone No.'**
  String get phoneno;

  /// No description provided for @timeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timeline;

  /// No description provided for @checklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get checklist;

  /// No description provided for @addNewEvent.
  ///
  /// In en, this message translates to:
  /// **'Add New Event'**
  String get addNewEvent;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title *'**
  String get title;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start Time *'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End Time *'**
  String get endTime;

  /// No description provided for @locationoptional.
  ///
  /// In en, this message translates to:
  /// **'Location (optional)'**
  String get locationoptional;

  /// No description provided for @descriptionoptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionoptional;

  /// No description provided for @linkoptional.
  ///
  /// In en, this message translates to:
  /// **'Link (optional)'**
  String get linkoptional;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @addEvent.
  ///
  /// In en, this message translates to:
  /// **'Add Event'**
  String get addEvent;

  /// No description provided for @addNewTask.
  ///
  /// In en, this message translates to:
  /// **'Add New Task'**
  String get addNewTask;

  /// No description provided for @createNewProject.
  ///
  /// In en, this message translates to:
  /// **'Create New Project'**
  String get createNewProject;

  /// No description provided for @projectTittle.
  ///
  /// In en, this message translates to:
  /// **'Project Tittle *'**
  String get projectTittle;

  /// No description provided for @createProject.
  ///
  /// In en, this message translates to:
  /// **'Create Project'**
  String get createProject;

  /// No description provided for @pleasecreateaprojectfirst.
  ///
  /// In en, this message translates to:
  /// **'Please create project first'**
  String get pleasecreateaprojectfirst;

  /// No description provided for @project.
  ///
  /// In en, this message translates to:
  /// **'Project *'**
  String get project;

  /// No description provided for @taskTittle.
  ///
  /// In en, this message translates to:
  /// **'Task Tittle *'**
  String get taskTittle;

  /// No description provided for @dueDate.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get dueDate;

  /// No description provided for @addTask.
  ///
  /// In en, this message translates to:
  /// **'Add Task'**
  String get addTask;

  /// No description provided for @editTask.
  ///
  /// In en, this message translates to:
  /// **'Edit Task'**
  String get editTask;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @deleteTask.
  ///
  /// In en, this message translates to:
  /// **'Delete Task'**
  String get deleteTask;

  /// No description provided for @areyousureyouwanttodeletethistask.
  ///
  /// In en, this message translates to:
  /// **'Are you sure want to delete this task?'**
  String get areyousureyouwanttodeletethistask;

  /// No description provided for @deleteProject.
  ///
  /// In en, this message translates to:
  /// **'Delete Project'**
  String get deleteProject;

  /// No description provided for @areyousureyouwanttodeletethisprojectAlltasksinthisprojectwillalsobedeleted.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this project? All in this project  will also be deleted.'**
  String get areyousureyouwanttodeletethisprojectAlltasksinthisprojectwillalsobedeleted;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @taskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Task Completed'**
  String get taskCompleted;

  /// No description provided for @taskmanager1.
  ///
  /// In en, this message translates to:
  /// **'Task Manager'**
  String get taskmanager1;

  /// No description provided for @requiredDocuments.
  ///
  /// In en, this message translates to:
  /// **'Required Documents'**
  String get requiredDocuments;

  /// No description provided for @uploadtherequiredfiles.
  ///
  /// In en, this message translates to:
  /// **'Upload the required files'**
  String get uploadtherequiredfiles;

  /// No description provided for @privateDetailsandCerts.
  ///
  /// In en, this message translates to:
  /// **'Private Details and Certs'**
  String get privateDetailsandCerts;

  /// No description provided for @uploadRequired.
  ///
  /// In en, this message translates to:
  /// **'Upload Required'**
  String get uploadRequired;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @perksandfacilities.
  ///
  /// In en, this message translates to:
  /// **'Perks & Facilities'**
  String get perksandfacilities;

  /// No description provided for @benefitsOverview1.
  ///
  /// In en, this message translates to:
  /// **'Benefits Overview'**
  String get benefitsOverview1;

  /// No description provided for @yourofficelocation.
  ///
  /// In en, this message translates to:
  /// **'Your Office Location'**
  String get yourofficelocation;

  /// No description provided for @canteenmenu.
  ///
  /// In en, this message translates to:
  /// **'Canteen Menu'**
  String get canteenmenu;

  /// No description provided for @parkinginformation.
  ///
  /// In en, this message translates to:
  /// **'Parking Information'**
  String get parkinginformation;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @officelocation.
  ///
  /// In en, this message translates to:
  /// **'Office Location'**
  String get officelocation;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// No description provided for @interactiveMap.
  ///
  /// In en, this message translates to:
  /// **'Interactive Map'**
  String get interactiveMap;

  /// No description provided for @tapToOpenInMaps.
  ///
  /// In en, this message translates to:
  /// **'Tap to Open in Maps'**
  String get tapToOpenInMaps;

  /// No description provided for @getDirections.
  ///
  /// In en, this message translates to:
  /// **'Get Directions'**
  String get getDirections;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @officeFacilities.
  ///
  /// In en, this message translates to:
  /// **'Office Facilities'**
  String get officeFacilities;

  /// No description provided for @parkingPage.
  ///
  /// In en, this message translates to:
  /// **'Parking Page'**
  String get parkingPage;

  /// No description provided for @car.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get car;

  /// No description provided for @motorcycle.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get motorcycle;

  /// No description provided for @learninghub1.
  ///
  /// In en, this message translates to:
  /// **'Learning Hub'**
  String get learninghub1;

  /// No description provided for @allLearning.
  ///
  /// In en, this message translates to:
  /// **'All Learning'**
  String get allLearning;

  /// No description provided for @noCourseFound.
  ///
  /// In en, this message translates to:
  /// **'No Course Found'**
  String get noCourseFound;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ms'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'ms': return AppLocalizationsMs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}