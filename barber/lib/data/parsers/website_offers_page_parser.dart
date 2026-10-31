import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../core/config/booking_policy.dart';
import '../../domain/models/website_offers_page_data.dart';

/// Reads semantic elements rather than depending on attribute order or exact
/// class strings. Unknown markup never revives a hard-coded, expired offer.
class WebsiteOffersPageParser {
  const WebsiteOffersPageParser();

  WebsiteOffersPageData parse({
    required String salonId,
    required Uri pageUrl,
    required String html,
    DateTime? now,
  }) {
    final document = html_parser.parse(html);
    final instant = now ?? DateTime.now();
    final sections = <WebsiteOfferSection>[];

    for (final campaign in document.querySelectorAll('.hw')) {
      if (!_visible(campaign)) continue;
      final accessibleTitle = _text(campaign.querySelector('.hw-sr'));
      final heading = accessibleTitle.isNotEmpty
          ? accessibleTitle
          : _text(campaign.querySelector('.hw-titre'));
      if (heading.isEmpty) continue;
      final discount = RegExp(r'^[-−]?\d+\s*%').firstMatch(heading)?.group(0);
      sections.add(
        WebsiteOfferSection.current(
          sectionLabel: _text(campaign.querySelector('.hw-kicker')),
          badge: _text(campaign.querySelector('.hw-kicker')),
          headline: discount ?? heading,
          subheadline: [
            _text(campaign.querySelector('.hw-titre-vu'), includeHidden: true),
            _text(
              campaign.querySelector('.hw-sous-titre'),
              includeHidden: true,
            ),
          ].where((s) => s.isNotEmpty).join(' — '),
          priceOld: '',
          priceNew: '',
          ctaLabel: _text(campaign.querySelector('.hw-cta')),
          footnote: _text(campaign.querySelector('.hw-salons')),
          details: [
            _text(campaign.querySelector('.hw-texte')),
            _text(campaign.querySelector('.hw-conditions')),
          ].where((s) => s.isNotEmpty).join('\n\n'),
          imageUrl: _asset(
            pageUrl,
            campaign.querySelector('.hw-media img')?.attributes['src'],
          ),
        ),
      );
    }

    final launch = document.querySelector('.launch-fine');
    if (launch != null && _visible(launch)) {
      final days =
          document
              .querySelectorAll('[data-date]')
              .map((e) => DateTime.tryParse(e.attributes['data-date'] ?? ''))
              .whereType<DateTime>()
              .toList()
            ..sort();
      final active =
          days.isNotEmpty &&
          instant.isBefore(
            BookingPolicy.parisDate(
              days.last.year,
              days.last.month,
              days.last.day + 1,
            ),
          );
      if (active) {
        sections.add(
          WebsiteOfferSection.current(
            sectionLabel: _text(document.querySelector('.launch-kicker')),
            badge: _text(document.querySelector('.launch-status')),
            headline: _text(document.querySelector('.launch-num')),
            subheadline: _text(document.querySelector('.launch-num-sub')),
            priceOld: _text(document.querySelector('.lp-old')),
            priceNew: _text(document.querySelector('.lp-new')),
            ctaLabel: _text(
              document.querySelector('.launch-ctas .btn-primary'),
            ),
            footnote: _text(document.querySelector('.launch-month')),
            details: _text(launch),
            imageUrl: '',
          ),
        );
      }
    }

    for (final card in document.querySelectorAll('.mardi-card')) {
      if (!_visible(card)) continue;
      final headline = _text(
        card.querySelector('.mardi-headline'),
        preserveLines: true,
      );
      if (headline.isEmpty) continue;
      sections.add(
        WebsiteOfferSection.current(
          sectionLabel: _text(
            _ancestor(
              card,
              (e) => e.localName == 'section',
            )?.querySelector('.section-title'),
          ),
          badge: _text(card.querySelector('.mardi-badge')),
          headline: headline,
          subheadline: _text(card.querySelector('.mardi-sub')),
          priceOld: _text(card.querySelector('.mardi-price-old')),
          priceNew: _text(card.querySelector('.mardi-price-new')),
          ctaLabel: _text(card.querySelector('.mardi-cta')),
          footnote: _text(card.querySelector('.mardi-foot')),
          details: _text(card.querySelector('.mardi-conditions')),
          imageUrl: _asset(
            pageUrl,
            card.querySelector('.mardi-bg img')?.attributes['src'],
          ),
        ),
      );
    }

    final upcoming = document.querySelector('#tab-upcoming');
    if (upcoming != null) {
      final headline = _text(upcoming.querySelector('.mystery-number'));
      final target = _countdownTarget(html);
      if (headline.isNotEmpty && (target == null || instant.isBefore(target))) {
        sections.add(
          WebsiteOfferSection.upcoming(
            sectionLabel: _text(upcoming.querySelector('.section-title')),
            badge: _text(upcoming.querySelector('.mystery-badge')),
            headline: headline,
            subheadline: _text(upcoming.querySelector('.mystery-ans')),
            description: _text(upcoming.querySelector('.mystery-tagline')),
            ctaLabel: _text(upcoming.querySelector('#notifyBtn')),
            details: _text(upcoming.querySelector('.mystery-note')),
            countdownTarget: target,
            alertConfig: _alertConfig(document, html),
            imageUrl: _asset(
              pageUrl,
              upcoming.querySelector('.mystery-bg img')?.attributes['src'],
            ),
          ),
        );
      }
    }

    // An idle card with [hidden] is a future empty state, not a live offer.
    if (!sections.any((section) => section.isCurrent)) {
      for (final teaser in document.querySelectorAll('.teaser, .idle-card')) {
        if (!_visible(teaser)) continue;
        final title = _text(teaser.querySelector('.teaser-title, .idle-title'));
        if (title.isEmpty) continue;
        sections.add(
          WebsiteOfferSection.teaser(
            sectionLabel: title,
            headline: title,
            description: _text(
              teaser.querySelector('.teaser-desc, .idle-desc'),
            ),
          ),
        );
      }
      // Older launch pages published idle copy without an enclosing card.
      final idleTitle = document.querySelector('.idle-title');
      if (idleTitle != null &&
          _visible(idleTitle) &&
          !sections.any((section) => section.isTeaser)) {
        sections.add(
          WebsiteOfferSection.teaser(
            sectionLabel: _text(idleTitle),
            headline: _text(idleTitle),
            description: _text(document.querySelector('.idle-desc')),
          ),
        );
      }
    }

    final gift = document.querySelector('.gift-card');
    final giftCard = gift != null && _visible(gift)
        ? WebsiteGiftCardData(
            sectionLabel: _text(
              _ancestor(
                gift,
                (e) => e.classes.contains('gift-section'),
              )?.querySelector('.section-title'),
            ),
            watermark: _text(gift.querySelector('.gift-watermark')),
            label: _text(gift.querySelector('.gift-label')),
            title: _text(gift.querySelector('.gift-title')),
            price: _text(gift.querySelector('.gift-price')),
            description: _text(gift.querySelector('.gift-desc')),
            linkLabel: 'Réserver',
            linkUrl: _asset(pageUrl, gift.attributes['href']),
          )
        : WebsiteOffersPageData.unavailable(salonId, pageUrl).giftCard;

    return WebsiteOffersPageData(
      salonId: salonId.trim().toLowerCase(),
      pageUrl: pageUrl,
      pageTitle: _text(document.querySelector('title')),
      pageDescription:
          document
              .querySelector('meta[name="description"]')
              ?.attributes['content']
              ?.trim() ??
          '',
      sections: sections,
      giftCard: giftCard,
      conditions: document
          .querySelectorAll('.cond-text')
          .where(_visible)
          .map((e) => _text(e))
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList(),
      currentTabLabel: _optionalText(document.querySelector('#tabBtnCurrent')),
      upcomingTabLabel: _optionalText(
        document.querySelector('#tabBtnUpcoming'),
      ),
    );
  }

  Element? _ancestor(Element element, bool Function(Element) matches) {
    for (
      Element? current = element.parent;
      current != null;
      current = current.parent
    ) {
      if (matches(current)) return current;
    }
    return null;
  }

  bool _visible(Element element) {
    for (
      Element? current = element;
      current != null;
      current = current.parent
    ) {
      // Hidden tab panels remain valid published content; other hidden cards
      // (notably expired campaigns and placeholder empty states) do not.
      if (current.classes.contains('offer-panel')) continue;
      if (current.attributes.containsKey('hidden')) return false;
      if (RegExp(
        r'display\s*:\s*none',
        caseSensitive: false,
      ).hasMatch(current.attributes['style'] ?? '')) {
        return false;
      }
    }
    return true;
  }

  String? _optionalText(Element? element) {
    final text = _text(element);
    return text.isEmpty ? null : text;
  }

  String _text(
    Element? element, {
    bool preserveLines = false,
    bool includeHidden = false,
  }) {
    if (element == null) return '';
    final clone = element.clone(true);
    for (final node in clone.querySelectorAll(
      includeHidden
          ? 'svg, script, style'
          : 'svg, script, style, [aria-hidden="true"]',
    )) {
      node.remove();
    }
    for (final br in clone.querySelectorAll('br')) {
      br.replaceWith(Text(preserveLines ? '\n' : ' '));
    }
    return preserveLines
        ? clone.text.replaceAll(RegExp(r'[^\S\n]+'), ' ').trim()
        : clone.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _asset(Uri pageUrl, String? value) {
    if (value == null || value.trim().isEmpty) return '';
    final uri = pageUrl.resolve(value.trim());
    return ['https', 'http'].contains(uri.scheme) ? uri.toString() : '';
  }

  WebsiteAlertConfig? _alertConfig(Document document, String html) {
    final base = RegExp(
      r"""const API_BASE\s*=\s*window\.location\.hostname\s*===\s*['"]localhost['"][\s\S]*?:\s*['"]([^'"]+)['"]""",
    ).firstMatch(html)?.group(1);
    String? config(String key) => RegExp(
      '["\x27]?$key["\x27]?\\s*:\\s*["\x27]([^"\x27]+)["\x27]',
    ).firstMatch(html)?.group(1);
    final event = config('event_name');
    final salon = config('salon_id');
    final uri = base == null ? null : Uri.tryParse(base);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        event == null ||
        salon == null) {
      return null;
    }
    return WebsiteAlertConfig(
      apiBaseUrl: base!,
      eventName: event,
      salonId: salon,
      successMessage:
          _optionalText(document.querySelector('.alert-success')) ??
          'Vous serez alerté !',
      buttonLabel:
          _optionalText(document.querySelector('#notifyBtn')) ?? 'Être alerté',
      emailPlaceholder:
          document.querySelector('#alertEmail')?.attributes['placeholder'] ??
          'Votre email',
    );
  }

  DateTime? _countdownTarget(String html) {
    final match = RegExp(
      r'const TARGET\s*=\s*new Date\((\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)\)',
    ).firstMatch(html);
    if (match == null) return null;
    final values = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
    return BookingPolicy.parisDate(
      values[0],
      values[1] + 1,
      values[2],
      hour: values[3],
      minute: values[4],
      second: values[5],
    );
  }
}
