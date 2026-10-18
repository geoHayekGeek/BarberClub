import '../../domain/models/website_offers_page_data.dart';
import 'package:html/parser.dart' as html_parser;
import '../../core/config/booking_policy.dart';

class WebsiteOffersPageParser {
  const WebsiteOffersPageParser();

  WebsiteOffersPageData parse({
    required String salonId,
    required Uri pageUrl,
    required String html,
    DateTime? now,
  }) {
    final normalizedSalonId = salonId.trim().toLowerCase();
    final pageTitle = _cleanText(
      _firstGroup(
            html,
            RegExp(r'<title>([\s\S]*?)</title>', caseSensitive: false),
          ) ??
          _defaultTitle(normalizedSalonId),
    );
    final pageDescription = _cleanText(
      _firstGroup(
            html,
            RegExp(
              r'<meta\s+name="description"\s+content="([^"]+)"',
              caseSensitive: false,
            ),
          ) ??
          '',
    );

    final hasTabbedLayout = html.contains('id="offerTabs"');
    final sections = <WebsiteOfferSection>[];

    final document = html_parser.parse(html);
    final launch = document.querySelector('.launch-fine');
    if (launch != null) {
      final days =
          document
              .querySelectorAll('[data-date]')
              .map((e) => DateTime.tryParse(e.attributes['data-date'] ?? ''))
              .whereType<DateTime>()
              .toList()
            ..sort();
      final expired =
          days.isEmpty ||
          !(now ?? DateTime.now()).isBefore(
            BookingPolicy.parisDate(
              days.last.year,
              days.last.month,
              days.last.day + 1,
            ),
          );
      String content(String selector) =>
          document
              .querySelector(selector)
              ?.text
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim() ??
          '';
      if (!expired) {
        sections.add(
          WebsiteOfferSection.current(
            sectionLabel: content('.launch-kicker'),
            badge: content('.launch-status'),
            headline: content('.launch-num'),
            subheadline: content('.launch-num-sub'),
            priceOld: content('.lp-old'),
            priceNew: content('.lp-new'),
            ctaLabel: content('.launch-ctas .btn-primary'),
            footnote: content('.launch-month'),
            details: content('.launch-fine'),
            imageUrl: '',
          ),
        );
      } else {
        sections.add(
          WebsiteOfferSection.teaser(
            sectionLabel: 'Offres',
            headline: content('.idle-title'),
            description: content('.idle-desc'),
          ),
        );
      }
    }

    if (sections.isNotEmpty) {
      // Launch pages have their own layout, dates, and pricing examples.
    } else if (hasTabbedLayout) {
      final currentSection = _parseCurrentSection(html, pageUrl);
      if (currentSection != null) {
        sections.add(currentSection);
      }

      final upcomingSection = _parseUpcomingSection(html, pageUrl);
      if (upcomingSection != null) {
        sections.add(upcomingSection);
      }
    } else {
      final teaserSection = _parseTeaserSection(html);
      if (teaserSection != null) {
        sections.add(teaserSection);
      }
    }

    final giftCard =
        _parseGiftCard(html, pageUrl) ??
        _fallbackGiftCard(normalizedSalonId, pageUrl);
    final conditions = _parseConditions(html, normalizedSalonId);
    final currentTabLabel = _parseTabLabel(html, true);
    final upcomingTabLabel = _parseTabLabel(html, false);

    if (sections.isEmpty) {
      return _fallbackPage(
        salonId: normalizedSalonId,
        pageUrl: pageUrl,
        pageTitle: pageTitle,
        pageDescription: pageDescription,
      );
    }

    return WebsiteOffersPageData(
      salonId: normalizedSalonId,
      pageUrl: pageUrl,
      pageTitle: pageTitle,
      pageDescription: pageDescription,
      sections: sections,
      giftCard: giftCard,
      conditions: conditions,
      currentTabLabel: currentTabLabel,
      upcomingTabLabel: upcomingTabLabel,
    );
  }

  WebsiteOffersPageData _fallbackPage({
    required String salonId,
    required Uri pageUrl,
    required String pageTitle,
    required String pageDescription,
  }) {
    return WebsiteOffersPageData.unavailable(salonId, pageUrl);
  }

  WebsiteOfferSection? _parseCurrentSection(String html, Uri pageUrl) {
    final sectionHtml = _firstGroup(
      html,
      RegExp(
        r'<section class="offer-panel" id="tab-current"[\s\S]*?</section>',
        caseSensitive: false,
      ),
      group: 0,
    );
    if (sectionHtml == null) return null;

    final cardHtml = _firstGroup(
      sectionHtml,
      RegExp(
        r'<a href="([^"]+)" class="mardi-card"[\s\S]*?</a>',
        caseSensitive: false,
      ),
      group: 0,
    );
    if (cardHtml == null) return null;

    return WebsiteOfferSection.current(
      sectionLabel: _cleanText(
        _firstGroup(
              sectionHtml,
              RegExp(
                r'<h2 class="section-title">([\s\S]*?)</h2>',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
      badge: _cleanText(
        _firstGroup(
              cardHtml,
              RegExp(
                r'<span class="mardi-badge">([\s\S]*?)</span>',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
      headline: _cleanText(
        _firstGroup(
              cardHtml,
              RegExp(
                r'<span class="mardi-headline">([\s\S]*?)</span>',
                caseSensitive: false,
              ),
            ) ??
            '',
        preserveLineBreaks: true,
      ),
      subheadline: _cleanText(
        _firstGroup(
              cardHtml,
              RegExp(
                r'<span class="mardi-sub">([\s\S]*?)</span>',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
      priceOld: _cleanText(
        _firstGroup(
              cardHtml,
              RegExp(
                r'<s class="mardi-price-old">([\s\S]*?)</s>',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
      priceNew: _cleanText(
        _firstGroup(
              cardHtml,
              RegExp(
                r'<span class="mardi-price-new">([\s\S]*?)</span>',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
      ctaLabel: _cleanText(
        _firstGroup(
              cardHtml,
              RegExp(
                r'<span class="mystery-cta mardi-cta">([\s\S]*?)</span>',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
      footnote: _cleanText(
        _firstGroup(
              cardHtml,
              RegExp(
                r'<span class="mardi-foot">([\s\S]*?)</span>',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
      details: _cleanText(
        _firstGroup(
              cardHtml,
              RegExp(
                r'<span class="mardi-conditions">([\s\S]*?)</span>',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
      imageUrl: _resolveRelativeUrl(
        pageUrl,
        _firstGroup(
              cardHtml,
              RegExp(
                r'<span class="mardi-bg"[^>]*><img src="([^"]+)"',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
    );
  }

  WebsiteOfferSection? _parseUpcomingSection(String html, Uri pageUrl) {
    final sectionHtml = _firstGroup(
      html,
      RegExp(
        r'<section class="offer-panel" id="tab-upcoming"[\s\S]*?</section>',
        caseSensitive: false,
      ),
      group: 0,
    );
    if (sectionHtml == null) return null;

    // The live site's event configuration is in a page-level script after the
    // panel, not inside it. Never replace missing configuration with old data.
    final alertConfig = _parseAlertConfig(html);
    final countdownTarget = _parseCountdownTarget(html);

    return WebsiteOfferSection.upcoming(
      sectionLabel: _cleanText(
        _firstGroup(
              sectionHtml,
              RegExp(
                r'<h2 class="section-title">([\s\S]*?)</h2>',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
      badge: _cleanText(
        _firstGroup(
              sectionHtml,
              RegExp(
                r'<div class="mystery-badge">([\s\S]*?)</div>',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
      headline: _cleanText(
        _firstGroup(
              sectionHtml,
              RegExp(
                r'<div class="mystery-number"[^>]*>([\s\S]*?)</div>',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
      subheadline: _cleanText(
        _firstGroup(
              sectionHtml,
              RegExp(
                r'<div class="mystery-ans">([\s\S]*?)</div>',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
      description: _cleanText(
        _firstGroup(
              sectionHtml,
              RegExp(
                r'<div class="mystery-tagline">([\s\S]*?)</div>',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
      ctaLabel: _cleanText(
        _firstGroup(
              sectionHtml,
              RegExp(
                r'<button class="mystery-cta" id="notifyBtn" type="button">([\s\S]*?)</button>',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
      details: _cleanText(
        _firstGroup(
              sectionHtml,
              RegExp(
                r'<div class="mystery-note">([\s\S]*?)</div>',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
      countdownTarget: countdownTarget,
      alertConfig: alertConfig,
      imageUrl: _resolveRelativeUrl(
        pageUrl,
        _firstGroup(
              sectionHtml,
              RegExp(
                r'<div class="mystery-bg">\s*<img src="([^"]+)"',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
    );
  }

  WebsiteOfferSection? _parseTeaserSection(String html) {
    final teaserHtml = _blockBetween(
      html,
      '<div class="teaser rv"',
      '<div class="gift-section',
    );
    if (teaserHtml == null) return null;

    final title = _cleanText(
      _firstGroup(
            teaserHtml,
            RegExp(
              r'<div class="teaser-title">([\s\S]*?)</div>',
              caseSensitive: false,
            ),
          ) ??
          '',
    );
    final description = _cleanText(
      _firstGroup(
            teaserHtml,
            RegExp(
              r'<div class="teaser-desc">([\s\S]*?)</div>',
              caseSensitive: false,
            ),
          ) ??
          '',
    );

    return WebsiteOfferSection.teaser(
      sectionLabel: title,
      headline: title,
      description: description,
    );
  }

  WebsiteGiftCardData? _parseGiftCard(String html, Uri pageUrl) {
    final giftHtml = _firstGroup(
      html,
      RegExp(
        r'<a href="([^"]+)" class="gift-card"[\s\S]*?</a>',
        caseSensitive: false,
      ),
      group: 0,
    );
    if (giftHtml == null) return null;

    return WebsiteGiftCardData(
      sectionLabel: _cleanText(
        _firstGroup(
              giftHtml,
              RegExp(
                r'<h2 class="section-title">([\s\S]*?)</h2>',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
      watermark: _cleanText(
        _firstGroup(
              giftHtml,
              RegExp(
                r'<span class="gift-watermark">([\s\S]*?)</span>',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
      label: _cleanText(
        _firstGroup(
              giftHtml,
              RegExp(
                r'<div class="gift-label">([\s\S]*?)</div>',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
      title: _cleanText(
        _firstGroup(
              giftHtml,
              RegExp(
                r'<div class="gift-title">([\s\S]*?)</div>',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
      price: _cleanText(
        _firstGroup(
              giftHtml,
              RegExp(
                r'<div class="gift-price">([\s\S]*?)</div>',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
      description: _cleanText(
        _firstGroup(
              giftHtml,
              RegExp(
                r'<div class="gift-desc">([\s\S]*?)</div>',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
      linkLabel: 'Réserver',
      linkUrl: _resolveRelativeUrl(
        pageUrl,
        _firstGroup(
              giftHtml,
              RegExp(
                r'<a href="([^"]+)" class="gift-card"',
                caseSensitive: false,
              ),
            ) ??
            '',
      ),
    );
  }

  WebsiteGiftCardData _fallbackGiftCard(String salonId, Uri pageUrl) {
    return WebsiteOffersPageData.unavailable(salonId, pageUrl).giftCard;
  }

  List<String> _parseConditions(String html, String salonId) {
    final matches = RegExp(
      r'<div class="cond-text">([\s\S]*?)</div>',
      caseSensitive: false,
    ).allMatches(html);
    final conditions = matches
        .map((match) => _cleanText(match.group(1) ?? ''))
        .where((text) => text.isNotEmpty)
        .toList();

    if (conditions.isNotEmpty) return conditions;

    return const [];
  }

  WebsiteAlertConfig? _parseAlertConfig(String sectionHtml) {
    final apiBaseUrl = _firstGroup(
      sectionHtml,
      RegExp(
        r"const API_BASE = window\.location\.hostname === 'localhost'[\s\S]*?:\s*'([^']+)'",
        caseSensitive: false,
      ),
    );
    final eventName = _firstGroup(
      sectionHtml,
      RegExp(r"event_name:\s*'([^']+)'", caseSensitive: false),
    );
    final salonId = _firstGroup(
      sectionHtml,
      RegExp(r"salon_id:\s*'([^']+)'", caseSensitive: false),
    );
    final successMessage = _cleanText(
      _firstGroup(
            sectionHtml,
            RegExp(
              r'<div class="alert-success"[^>]*>([\s\S]*?)</div>',
              caseSensitive: false,
            ),
          ) ??
          'Vous serez alerté !',
    );
    final buttonLabel = _cleanText(
      _firstGroup(
            sectionHtml,
            RegExp(
              r'<button class="mystery-cta" id="notifyBtn" type="button">([\s\S]*?)</button>',
              caseSensitive: false,
            ),
          ) ??
          'Être alerté',
    );
    final emailPlaceholder =
        _firstGroup(
          sectionHtml,
          RegExp(
            r'<input type="email" id="alertEmail" class="alert-input" placeholder="([^"]+)"',
            caseSensitive: false,
          ),
        ) ??
        'Votre email';

    if (apiBaseUrl == null || eventName == null || salonId == null) {
      return null;
    }

    return WebsiteAlertConfig(
      apiBaseUrl: apiBaseUrl,
      eventName: eventName,
      salonId: salonId,
      successMessage: successMessage,
      buttonLabel: buttonLabel,
      emailPlaceholder: emailPlaceholder,
    );
  }

  DateTime? _parseCountdownTarget(String sectionHtml) {
    final match = RegExp(
      r'const TARGET = new Date\((\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)\)\.getTime\(\);',
      caseSensitive: false,
    ).firstMatch(sectionHtml);
    if (match == null) return null;

    final year = int.tryParse(match.group(1) ?? '');
    final monthIndex = int.tryParse(match.group(2) ?? '');
    final day = int.tryParse(match.group(3) ?? '');
    final hour = int.tryParse(match.group(4) ?? '');
    final minute = int.tryParse(match.group(5) ?? '');
    final second = int.tryParse(match.group(6) ?? '');

    if (year == null ||
        monthIndex == null ||
        day == null ||
        hour == null ||
        minute == null ||
        second == null) {
      return null;
    }

    return DateTime(year, monthIndex + 1, day, hour, minute, second);
  }

  String? _parseTabLabel(String html, bool current) {
    final regex = current
        ? RegExp(
            r'<button class="offer-tab active"[^>]*>([\s\S]*?)</button>',
            caseSensitive: false,
          )
        : RegExp(
            r'<button class="offer-tab"(?! active)[^>]*>([\s\S]*?)</button>',
            caseSensitive: false,
          );
    final raw = _firstGroup(html, regex);
    if (raw == null) return null;
    final text = _cleanText(raw);
    return text.isEmpty ? null : text;
  }

  String _defaultTitle(String salonId) {
    return 'Offres & Événements';
  }

  String _resolveRelativeUrl(Uri pageUrl, String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) return parsed.toString();
    return pageUrl.resolve(trimmed).toString();
  }

  String? _firstGroup(String input, RegExp pattern, {int group = 1}) {
    final match = pattern.firstMatch(input);
    if (match == null) return null;
    if (group == 0) return match.group(0);
    return match.group(group);
  }

  String? _blockBetween(String input, String startMarker, String endMarker) {
    final start = input.indexOf(startMarker);
    if (start == -1) return null;
    final end = input.indexOf(endMarker, start + startMarker.length);
    final finish = end == -1 ? input.length : end;
    return input.substring(start, finish);
  }

  String _cleanText(String html, {bool preserveLineBreaks = false}) {
    var text = html
        .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>', caseSensitive: false), '');
    text = _decodeHtmlEntities(text);

    if (preserveLineBreaks) {
      text = text
          .replaceAll(RegExp(r'[ \t\r\f\v]+'), ' ')
          .replaceAll(RegExp(r'\n[ \t\r\f\v]+'), '\n')
          .replaceAll(RegExp(r'[ \t\r\f\v]+\n'), '\n');
      return text.trim();
    }

    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _decodeHtmlEntities(String input) {
    const replacements = {
      '&nbsp;': ' ',
      '&amp;': '&',
      '&quot;': '"',
      '&apos;': '\'',
      '&#39;': '\'',
      '&lt;': '<',
      '&gt;': '>',
      '&ndash;': '–',
      '&mdash;': '—',
      '&rsquo;': '’',
      '&lsquo;': '‘',
      '&laquo;': '«',
      '&raquo;': '»',
      '&eacute;': 'é',
      '&Eacute;': 'É',
      '&egrave;': 'è',
      '&Egrave;': 'È',
      '&ecirc;': 'ê',
      '&Ecirc;': 'Ê',
      '&agrave;': 'à',
      '&Agrave;': 'À',
      '&ccedil;': 'ç',
      '&Ccedil;': 'Ç',
      '&ocirc;': 'ô',
      '&Ocirc;': 'Ô',
      '&ucirc;': 'û',
      '&Ucirc;': 'Û',
      '&icirc;': 'î',
      '&Icirc;': 'Î',
      '&auml;': 'ä',
      '&Auml;': 'Ä',
      '&ouml;': 'ö',
      '&Ouml;': 'Ö',
      '&uuml;': 'ü',
      '&Uuml;': 'Ü',
    };

    var output = input;
    replacements.forEach((entity, value) {
      output = output.replaceAll(entity, value);
    });

    output = output.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final codePoint = int.tryParse(match.group(1) ?? '');
      if (codePoint == null) return match.group(0) ?? '';
      return String.fromCharCode(codePoint);
    });

    return output;
  }
}
