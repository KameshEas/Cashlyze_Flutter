import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_ta.dart';

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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('ta'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Cashlyze'**
  String get appTitle;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @emiTracker.
  ///
  /// In en, this message translates to:
  /// **'EMI Tracker'**
  String get emiTracker;

  /// No description provided for @recentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get recentTransactions;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get filterIncome;

  /// No description provided for @filterExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get filterExpense;

  /// No description provided for @uncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get uncategorized;

  /// No description provided for @addTransaction.
  ///
  /// In en, this message translates to:
  /// **'Add transaction'**
  String get addTransaction;

  /// No description provided for @deleteTransactionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete transaction'**
  String get deleteTransactionTitle;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions'**
  String get noTransactions;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date:'**
  String get dateLabel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @transactionSaved.
  ///
  /// In en, this message translates to:
  /// **'Transaction saved'**
  String get transactionSaved;

  /// No description provided for @transactionUpdated.
  ///
  /// In en, this message translates to:
  /// **'Transaction updated'**
  String get transactionUpdated;

  /// No description provided for @typeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get typeLabel;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @titleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleLabel;

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountLabel;

  /// No description provided for @amountHelperEg.
  ///
  /// In en, this message translates to:
  /// **'e.g., 123.45'**
  String get amountHelperEg;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expense;

  /// No description provided for @repeatLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeatLabel;

  /// No description provided for @monthlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthlyLabel;

  /// No description provided for @weeklyLabel.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weeklyLabel;

  /// No description provided for @frequencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequencyLabel;

  /// No description provided for @draftSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved'**
  String get draftSaved;

  /// No description provided for @enterTitleError.
  ///
  /// In en, this message translates to:
  /// **'Enter a title'**
  String get enterTitleError;

  /// No description provided for @enterValidAmountError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get enterValidAmountError;

  /// No description provided for @enterValidDateError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid date'**
  String get enterValidDateError;

  /// No description provided for @manageCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Categories'**
  String get manageCategoriesTitle;

  /// No description provided for @noCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories'**
  String get noCategories;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get addCategory;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @deleteCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete category'**
  String get deleteCategoryTitle;

  /// No description provided for @deleteCategoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this category?'**
  String get deleteCategoryConfirm;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// No description provided for @addCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Category'**
  String get addCategoryTitle;

  /// No description provided for @editCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Category'**
  String get editCategoryTitle;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @nameEmptyError.
  ///
  /// In en, this message translates to:
  /// **'Name cannot be empty'**
  String get nameEmptyError;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @quickTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get quickTransfer;

  /// No description provided for @quickTopUp.
  ///
  /// In en, this message translates to:
  /// **'Top-up'**
  String get quickTopUp;

  /// No description provided for @quickBill.
  ///
  /// In en, this message translates to:
  /// **'Bill'**
  String get quickBill;

  /// No description provided for @quickMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get quickMore;

  /// No description provided for @emiUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming EMI'**
  String get emiUpcoming;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @noUpcomingEmi.
  ///
  /// In en, this message translates to:
  /// **'No upcoming EMI this month'**
  String get noUpcomingEmi;

  /// No description provided for @setReminder.
  ///
  /// In en, this message translates to:
  /// **'Set Reminder'**
  String get setReminder;

  /// No description provided for @pay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get pay;

  /// No description provided for @emiMarkedPaidAdded.
  ///
  /// In en, this message translates to:
  /// **'EMI marked paid and transaction added'**
  String get emiMarkedPaidAdded;

  /// No description provided for @net.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get net;

  /// No description provided for @preferencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferencesTitle;

  /// No description provided for @alertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alertsTitle;

  /// No description provided for @alertsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notify when budgets approach thresholds'**
  String get alertsSubtitle;

  /// No description provided for @biometricRequireTitle.
  ///
  /// In en, this message translates to:
  /// **'Require biometric to unlock'**
  String get biometricRequireTitle;

  /// No description provided for @biometricRequireSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Prompt biometric on app launch'**
  String get biometricRequireSubtitle;

  /// No description provided for @developerOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Developer Options'**
  String get developerOptionsTitle;

  /// No description provided for @developerOptionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show advanced tools like backup/restore'**
  String get developerOptionsSubtitle;

  /// No description provided for @dataPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Data & Privacy'**
  String get dataPrivacyTitle;

  /// No description provided for @categoriesManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesManageTitle;

  /// No description provided for @categoriesManageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage categories'**
  String get categoriesManageSubtitle;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Onboarding'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Revisit walkthrough'**
  String get onboardingSubtitle;

  /// No description provided for @emiTrackerTitle.
  ///
  /// In en, this message translates to:
  /// **'EMI Tracker'**
  String get emiTrackerTitle;

  /// No description provided for @addEmiPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Add EMI Plan'**
  String get addEmiPlanTitle;

  /// No description provided for @addEmiPlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create plan'**
  String get addEmiPlanSubtitle;

  /// No description provided for @backupToFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup to File'**
  String get backupToFileTitle;

  /// No description provided for @backupToFileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save JSON and share'**
  String get backupToFileSubtitle;

  /// No description provided for @backupToDriveTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup to Drive'**
  String get backupToDriveTitle;

  /// No description provided for @backupToDriveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload JSON to Drive'**
  String get backupToDriveSubtitle;

  /// No description provided for @restoreFromFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from File'**
  String get restoreFromFileTitle;

  /// No description provided for @restoreFromFileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import JSON backup'**
  String get restoreFromFileSubtitle;

  /// No description provided for @restoreFromDriveTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from Drive'**
  String get restoreFromDriveTitle;

  /// No description provided for @restoreFromDriveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download & import JSON'**
  String get restoreFromDriveSubtitle;

  /// No description provided for @exportDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get exportDataTitle;

  /// No description provided for @exportDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Copy JSON to clipboard'**
  String get exportDataSubtitle;

  /// No description provided for @clearAllDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear All Data'**
  String get clearAllDataTitle;

  /// No description provided for @clearAllDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Requires typing DELETE and export acknowledgment'**
  String get clearAllDataSubtitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'ta':
      return AppLocalizationsTa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
