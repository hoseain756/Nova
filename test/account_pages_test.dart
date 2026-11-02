import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/account/account_pages.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';

Widget _app(Widget page,
        {Locale locale = const Locale('en'),
        TextScaler textScaler = TextScaler.noScaling}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        NovaStrings.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      theme: NovaTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: page,
    );

void main() {
  testWidgets('welcome offers all three paths in English', (tester) async {
    var login = 0;
    var create = 0;
    var guest = 0;
    await tester.pumpWidget(_app(AccountWelcomePage(
      onLogIn: () => login++,
      onCreateAccount: () => create++,
      onContinueAsGuest: () async => guest++,
    )));
    await tester.tap(find.text('Log in'));
    await tester.tap(find.text('Create account'));
    await tester.tap(find.text('Continue as guest'));
    await tester.pump();
    expect((login, create, guest), (1, 1, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic welcome remains usable at narrow width', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(
      AccountWelcomePage(
        onLogIn: () {},
        onCreateAccount: () {},
        onContinueAsGuest: () async {},
      ),
      locale: const Locale('ar'),
      textScaler: const TextScaler.linear(1.6),
    ));
    expect(find.text('المتابعة كضيف'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile picker requires PIN before callback', (tester) async {
    String? selectedId;
    String? selectedPin;
    await tester.pumpWidget(_app(ProfilePickerPage(
      profiles: const [
        ProfileSummary(id: 'one', name: 'Sam', hasPin: true),
      ],
      onSelect: (id, pin) async {
        selectedId = id;
        selectedPin = pin;
      },
    )));
    await tester.tap(find.text('Sam').first);
    await tester.pumpAndSettle();
    expect(selectedId, isNull);
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(selectedId, 'one');
    expect(selectedPin, '123456');
  });

  testWidgets('profile editor sends name, avatar, and default choice',
      (tester) async {
    ProfileDraft? draft;
    await tester.pumpWidget(_app(ProfileEditorPage(
      firstProfile: true,
      onSave: (value) async => draft = value,
    )));
    await tester.enterText(find.byType(TextFormField).first, 'Family');
    await tester.ensureVisible(find.text('Set as default profile'));
    await tester.tap(find.byType(Switch).last);
    await tester.ensureVisible(find.text('Save profile'));
    await tester.tap(find.text('Save profile'));
    await tester.pump();
    expect(draft?.name, 'Family');
    expect(novaAvatarPackKeys, contains(draft?.avatarPackKey));
    expect(draft?.setAsDefault, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final (locale, theme) in <(Locale, ThemeData)>[
    (const Locale('en'), NovaTheme.light),
    (const Locale('ar'), NovaTheme.dark),
  ]) {
    testWidgets(
        'profile image preview follows the avatar in ${locale.languageCode}',
        (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          NovaStrings.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: theme,
        home: ProfileEditorPage(onSave: (_) async {}),
      ));
      final preview = find.byType(ProfileAvatar).first;
      final avatarRect = tester.getRect(preview);
      final nameRect = tester.getRect(find.byType(TextFormField).first);
      if (locale.languageCode == 'ar') {
        expect(avatarRect.left, greaterThan(nameRect.right));
      } else {
        expect(avatarRect.right, lessThan(nameRect.left));
      }
      final initial = tester.widget<ProfileAvatar>(preview).packKey;
      expect(novaAvatarPackKeys, contains(initial));
      await tester.ensureVisible(find.bySemanticsLabel(
          locale.languageCode == 'ar' ? 'الصورة الرمزية 2' : 'Avatar 2'));
      await tester.tap(find.bySemanticsLabel(
          locale.languageCode == 'ar' ? 'الصورة الرمزية 2' : 'Avatar 2'));
      await tester.pump();
      expect(
          tester.widget<ProfileAvatar>(preview).packKey, novaAvatarPackKeys[1]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('URL avatar shows the entered link and blocks invalid images',
      (tester) async {
    await tester.pumpWidget(_app(ProfileEditorPage(onSave: (_) async {})));
    await tester.tap(find.text('Image URL'));
    await tester.pump();
    final input = find.widgetWithText(TextFormField, 'Image URL');
    await tester.enterText(input, 'not-an-image-link');
    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.widget<ProfileAvatar>(find.byType(ProfileAvatar).first).url,
        'not-an-image-link');
    expect(find.text('Enter a valid HTTPS image URL.'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save profile'))
            .onPressed,
        isNull);
    await tester.enterText(input, 'https://example.com/avatar.png');
    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.widget<ProfileAvatar>(find.byType(ProfileAvatar).first).url,
        'https://example.com/avatar.png');
    await tester.pump(const Duration(seconds: 11));
    expect(
        find.text(
            'Could not load this image. Check that the link opens a public image file.'),
        findsOneWidget);
    await tester.ensureVisible(find.text('Retry image'));
    await tester.tap(find.text('Retry image'));
    await tester.pump();
    expect(tester.widget<ProfileAvatar>(find.byType(ProfileAvatar).first).url,
        'https://example.com/avatar.png');
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing a profile PIN requires its current PIN',
      (tester) async {
    ProfileDraft? draft;
    await tester.pumpWidget(_app(ProfileEditorPage(
      initial: const ProfileSummary(
        id: 'one',
        name: 'Family',
        hasPin: true,
      ),
      onSave: (value) async => draft = value,
    )));
    await tester.ensureVisible(find.text('Remove profile PIN'));
    await tester.tap(find.text('Remove profile PIN'));
    await tester.pump();
    await tester.ensureVisible(find.text('Current PIN'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Current PIN'), '654321');
    await tester.ensureVisible(find.text('Save profile'));
    await tester.tap(find.text('Save profile'));
    await tester.pump();
    expect(draft?.removePin, isTrue);
    expect(draft?.oldPin, '654321');
    expect(draft?.pin, isNull);
  });

  testWidgets(
      'password recovery shows retryable failure without account detail',
      (tester) async {
    await tester.pumpWidget(_app(AccountResetPage(
      onSubmit: (_) async => throw StateError('private backend detail'),
    )));
    await tester.enterText(find.byType(TextFormField), 'sam@example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    expect(
        find.text('Something went wrong. Please try again.'), findsOneWidget);
    expect(find.textContaining('private backend detail'), findsNothing);
    expect(find.text('Send reset link'), findsOneWidget);
  });

  testWidgets('invalid PIN blocks locked profile management actions',
      (tester) async {
    var verified = 0;
    var edited = 0;
    var deleted = 0;
    var defaulted = 0;
    await tester.pumpWidget(_app(ProfileManagementPage(
      profiles: const [
        ProfileSummary(id: 'locked', name: 'Locked', hasPin: true),
        ProfileSummary(id: 'other', name: 'Other'),
      ],
      onCreate: (_) async {},
      onUpdate: (id, draft) async => edited++,
      onDelete: (_) async => deleted++,
      onSetDefault: (_) async => defaulted++,
      onVerifyPin: (id, pin) async {
        verified++;
        return false;
      },
    )));

    Future<void> rejectPin() async {
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '111111');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Could not open this profile. Check the PIN and try again.'),
          findsOneWidget);
    }

    await tester.tap(find.byTooltip('Edit profile').first);
    await rejectPin();
    expect(find.byType(ProfileEditorPage), findsNothing);

    await tester.ensureVisible(find.byType(Switch).first);
    await tester.tap(find.byType(Switch).first);
    await rejectPin();

    await tester.ensureVisible(find.byTooltip('Delete profile').first);
    await tester.tap(find.byTooltip('Delete profile').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete profile'));
    await rejectPin();

    expect(verified, 3);
    expect(edited, 0);
    expect(deleted, 0);
    expect(defaulted, 0);
  });

  testWidgets('replacing a locked default also requires its PIN',
      (tester) async {
    var defaulted = 0;
    await tester.pumpWidget(_app(ProfileManagementPage(
      profiles: const [
        ProfileSummary(
            id: 'locked', name: 'Locked', hasPin: true, isDefault: true),
        ProfileSummary(id: 'other', name: 'Other'),
      ],
      onCreate: (_) async {},
      onUpdate: (id, draft) async {},
      onDelete: (_) async {},
      onSetDefault: (_) async => defaulted++,
      onVerifyPin: (id, pin) async => false,
    )));
    await tester.ensureVisible(find.byType(Switch).last);
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '111111');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(defaulted, 0);
    expect(
        find.text('Could not open this profile. Check the PIN and try again.'),
        findsOneWidget);
  });

  testWidgets('guest upgrade resumes pending email verification',
      (tester) async {
    var started = 0;
    await tester.pumpWidget(_app(GuestUpgradePage(
      emailVerified: false,
      initialSent: true,
      showBack: false,
      onStart: (username, email) async => started++,
      onFinish: (password) async {},
      onCheckVerification: () async {},
    )));
    expect(
        find.text(
            'Check your email and confirm the address, then return here.'),
        findsOneWidget);
    expect(find.text("I've verified my email"), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byTooltip('Back'), findsNothing);
    expect(started, 0);
  });

  testWidgets('editor cannot displace locked default without its PIN',
      (tester) async {
    var created = 0;
    await tester.pumpWidget(_app(ProfileManagementPage(
      profiles: const [
        ProfileSummary(
            id: 'locked', name: 'Locked', hasPin: true, isDefault: true),
      ],
      onCreate: (_) async => created++,
      onUpdate: (id, draft) async {},
      onDelete: (_) async {},
      onSetDefault: (_) async {},
      onVerifyPin: (id, pin) async => false,
    )));
    await tester.tap(find.text('Add profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'New');
    await tester.ensureVisible(find.byType(Switch).last);
    await tester.tap(find.byType(Switch).last);
    await tester.ensureVisible(find.text('Save profile'));
    await tester.tap(find.text('Save profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField).last, '111111');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(created, 0);
    expect(find.byType(ProfileEditorPage), findsOneWidget);
    expect(
        find.text('Could not open this profile. Check the PIN and try again.'),
        findsOneWidget);
  });
}
