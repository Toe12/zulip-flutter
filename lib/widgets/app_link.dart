import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../model/binding.dart';
import '../model/internal_link.dart';
import '../model/store.dart';
import 'app.dart';
import 'home.dart';
import 'message_list.dart';
import 'store.dart';

/// Opening, as a page in this app, a web link to one of our realms.
///
/// When someone taps a link such as `https://example.com/#narrow/channel/…`
/// in another app, and the system knows that this app handles links on
/// that domain (Universal Links on iOS, App Links on Android),
/// the system opens this app and gives it the link, instead of using
/// a browser.  We receive it as route information, or as the initial route
/// if that is what launched the app.
///
/// Only links to a narrow, or to a message, are opened; any other page of
/// the web app, like the help center, belongs in the browser.
abstract final class AppLink {
  /// The same link arriving twice within this time is opened once.
  ///
  /// When a link launches the app, the platform may report it both as the
  /// initial route and as route information; this keeps that from pushing the
  /// same page twice.
  static const _repeatWindow = Duration(seconds: 3);

  static String? _lastLink;
  static DateTime? _lastLinkTime;

  /// Reset the state of [AppLink], for testing.
  @visibleForTesting
  static void debugReset() {
    _lastLink = null;
    _lastLinkTime = null;
  }

  /// Whether [url] is shaped like a link into a narrow of a web app.
  ///
  /// This only looks at the URL's own form, not at whether any account
  /// is on that realm, or whether the narrow is one the app understands.
  static bool _isNarrowLinkShape(Uri url) {
    if (url.scheme != 'https' && url.scheme != 'http') return false;
    if (!isWebAppRootPath(url)) return false;
    if (url.hasQuery) return false;
    return url.fragment.split('/').first == 'narrow';
  }

  /// The account that the link [url] points into, or null if there is none.
  ///
  /// This is the account whose realm has the link's origin.
  /// If several accounts are on that realm, it is the last-visited one
  /// when that is among them.
  static Account? accountFor(GlobalStore globalStore, Uri url) {
    if (!_isNarrowLinkShape(url)) return null;
    final matching = globalStore.accounts
      .where((account) => account.realmUrl.origin == url.origin)
      .toList();
    final lastVisitedId = globalStore.lastVisitedAccount?.id;
    return matching.firstWhereOrNull((account) => account.id == lastVisitedId)
      ?? matching.firstOrNull;
  }

  /// The account to start in when the app was launched with [initialRoute],
  /// if that is a link into one of our realms; otherwise null.
  ///
  /// Use [openAfterStartup] to then go on to the link's page.
  static Account? accountForLaunch(GlobalStore globalStore, String initialRoute) {
    final url = Uri.tryParse(initialRoute);
    if (url == null) return null;
    return accountFor(globalStore, url);
  }

  /// Go on to the page for [initialRoute], once the app has started.
  ///
  /// Call this after [accountForLaunch] returned an account
  /// and the app began in the home page for that account.
  static void openAfterStartup(String initialRoute) {
    final url = Uri.tryParse(initialRoute);
    if (url == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      unawaited(open(url));
    });
  }

  /// Open the page that [url] is a link to, if it is a link we handle.
  ///
  /// This shows the home page of the account, then waits for that account's
  /// data, which is needed to understand the narrow, and opens the narrow.
  /// If the narrow isn't one the app can open, the account's home page is
  /// what is left showing.
  ///
  /// Does nothing if [url] isn't a link into a narrow on a realm
  /// that we have an account for.
  static Future<void> open(Uri url) async {
    if (!_isNarrowLinkShape(url)) return;
    if (_isRepeat(url)) return;

    final navigator = await ZulipApp.navigator;
    final context = navigator.context;
    if (!context.mounted) return;
    final globalStore = GlobalStoreWidget.of(context);

    final account = accountFor(globalStore, url);
    if (account == null) return; // TODO(log)

    if (ZulipApp.navigationStack!.currentAccountId != account.id) {
      HomePage.navigate(context, accountId: account.id);
    }

    final PerAccountStore store;
    try {
      store = await globalStore.perAccount(account.id);
    } catch (_) {
      // The home page for the account shows its own progress and errors.
      return; // TODO(log)
    }
    if (!navigator.mounted) return;

    var link = parseInternalLink(url, store);
    if (link is MessageIdLink) {
      try {
        link = await resolveMessageIdLink(store, link);
      } catch (_) {
        return; // TODO(log)
      }
      if (!navigator.mounted) return;
    }
    if (link is! NarrowLink) return;
    unawaited(navigator.push(MessageListPage.buildRoute(
      accountId: account.id,
      narrow: link.narrow,
      initAnchorMessageId: link.nearMessageId)));
  }

  static bool _isRepeat(Uri url) {
    final now = ZulipBinding.instance.utcNow();
    final link = url.toString();
    final isRepeat = link == _lastLink
      && _lastLinkTime != null
      && now.difference(_lastLinkTime!) < _repeatWindow;
    _lastLink = link;
    _lastLinkTime = now;
    return isRepeat;
  }
}
