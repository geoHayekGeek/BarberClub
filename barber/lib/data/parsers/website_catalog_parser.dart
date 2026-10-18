import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../domain/models/barber.dart';
import '../../domain/models/salon.dart';

/// Reads published content, preserving asset versions and website spelling.
/// Booking availability and prices remain the reservation API's responsibility.
class WebsiteCatalogParser {
  const WebsiteCatalogParser();

  List<String> salonIds(String html) {
    final document = html_parser.parse(html);
    return document
        .querySelectorAll('a[data-salon]')
        .map((node) {
          final path = Uri.tryParse(
            node.attributes['href'] ?? '',
          )?.pathSegments;
          final index = path?.indexOf('pages') ?? -1;
          return index >= 0 && path!.length > index + 1 ? path[index + 1] : '';
        })
        .where((id) => RegExp(r'^[a-z0-9-]+$').hasMatch(id))
        .toSet()
        .toList();
  }

  Salon salon({
    required String id,
    required Uri pageUrl,
    required String html,
  }) {
    final doc = html_parser.parse(html);
    final title = _text(doc.querySelector('.page-title'));
    if (title.isEmpty || doc.querySelector('.page-intro') == null) {
      throw const FormatException('The website salon page has changed.');
    }
    final city = title.replaceFirst(
      RegExp(r'^Salon\s+Barber\s?Club\s*', caseSensitive: false),
      '',
    );
    final intro = _text(doc.querySelector('.page-intro'));
    final images = <String>{
      if (_asset(
            pageUrl,
            doc.querySelector('.desktop-hero-img')?.attributes['src'],
          )
          case final String hero)
        hero,
      ...doc
          .querySelectorAll('.photo-item img')
          .map((e) => _asset(pageUrl, e.attributes['src']))
          .whereType<String>(),
    }.toList();
    String address = '';
    String? phone;
    for (final card in doc.querySelectorAll('.contact-card')) {
      final label = _text(
        card.querySelector('.contact-card-label'),
      ).toLowerCase();
      if (label == 'adresse')
        address = _text(card.querySelector('.contact-card-value'));
      if (label == 'téléphone')
        phone = _text(card.querySelector('.contact-card-value'));
    }
    const dayKeys = [
      'sunday',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
    ];
    final hours = <String, dynamic>{};
    final hoursText = <String>[];
    for (final row in doc.querySelectorAll('.hours-row')) {
      final day = int.tryParse(row.attributes['data-day'] ?? '');
      final value = _text(row.querySelector('.hours-time'));
      hoursText.add('${_text(row.querySelector('.hours-day'))} : $value');
      if (day == null || day < 0 || day > 6) continue;
      final closed = row.querySelector('.hours-time.closed') != null;
      final times = RegExp(
        r'(\d{1,2})h(?:\s*(\d{2}))?',
      ).allMatches(value).toList();
      if (closed) {
        hours[dayKeys[day]] = {'closed': true};
      } else if (times.length == 2) {
        String time(RegExpMatch m) =>
            '${m[1]!.padLeft(2, '0')}:${m[2] ?? '00'}';
        hours[dayKeys[day]] = {
          'closed': false,
          'open': time(times[0]),
          'close': time(times[1]),
        };
      }
    }
    final hoursNote = _text(doc.querySelector('.hours-note'));
    if (hoursNote.isNotEmpty) hoursText.add(hoursNote);
    return Salon(
      id: id,
      websiteId: id,
      name: title.replaceFirst(RegExp(r'^Salon\s+'), ''),
      city: city,
      descriptionShort: intro,
      descriptionLong: intro,
      location: _text(doc.querySelector('.page-subtitle')),
      address: address,
      phone: phone,
      images: images,
      services: const [],
      openingHours: hoursText.join('\n'),
      openingHoursStructured: hours.isEmpty ? null : hours,
      story: doc
          .querySelectorAll('.story-block p')
          .map(_text)
          .where((e) => e.isNotEmpty)
          .join('\n\n'),
      questions: doc
          .querySelectorAll('.faq-item')
          .map(
            (e) => SalonQuestion(
              question: _text(e.querySelector('summary')),
              answer: e.querySelectorAll('p').map(_text).join('\n'),
            ),
          )
          .where((e) => e.question.isNotEmpty && e.answer.isNotEmpty)
          .toList(),
      socialLinks: {
        for (final e in doc.querySelectorAll('a.social-link'))
          if (_asset(pageUrl, e.attributes['href']) case final String url)
            _text(e): url,
      },
    );
  }

  List<WebsiteBarberEntry> barbers({
    required Salon salon,
    required Uri pageUrl,
    required String html,
  }) {
    final doc = html_parser.parse(html);
    final cards = doc.querySelectorAll('a.barber-card');
    if (cards.isEmpty)
      throw const FormatException('The website team page has changed.');
    return cards
        .map((card) {
          final name = _text(card.querySelector('.barber-name'));
          final href = pageUrl.resolve(card.attributes['href'] ?? '');
          final profileSlug = href.pathSegments.last.replaceFirst(
            RegExp(r'\.html$'),
            '',
          );
          final key = profileSlug.startsWith('barber-')
              ? profileSlug.substring(7)
              : Uri.encodeComponent(name.toLowerCase());
          final photo = _asset(
            pageUrl,
            card.querySelector('img')?.attributes['src'],
          );
          return WebsiteBarberEntry(
            profileUrl: profileSlug.startsWith('barber-') ? href : null,
            barber: Barber(
              id: '${salon.id}--$key',
              firstName: name,
              lastName: '',
              displayName: name,
              bio: '',
              level: _text(card.querySelector('.barber-role')),
              specialties: const [],
              images: photo == null ? const [] : [photo],
              salons: [
                BarberSalon(id: salon.id, name: salon.name, city: salon.city),
              ],
            ),
          );
        })
        .where((e) => e.barber.displayName.isNotEmpty)
        .toList();
  }

  Barber barberDetail({
    required Barber summary,
    required Uri pageUrl,
    required String html,
  }) {
    final doc = html_parser.parse(html);
    final bio = doc
        .querySelectorAll('.bio-text')
        .map(_text)
        .where((e) => e.isNotEmpty)
        .join('\n\n');
    final heroVideo = _asset(
      pageUrl,
      doc
          .querySelector('.hero-media-wrap video source, .hero video source')
          ?.attributes['src'],
    );
    return Barber(
      id: summary.id,
      firstName: summary.firstName,
      lastName: summary.lastName,
      displayName: summary.displayName,
      bio: bio,
      level: _text(doc.querySelector('.profile-role')),
      specialties: const [],
      // The versioned team portrait takes precedence over unversioned profile images.
      images: [
        ...summary.images,
        ...doc
            .querySelectorAll('.gallery-item img')
            .map((e) => _asset(pageUrl, e.attributes['src']))
            .whereType<String>(),
      ],
      videoUrl: heroVideo,
      galleryVideoUrls: doc
          .querySelectorAll('.gallery-item video source')
          .map((e) => _asset(pageUrl, e.attributes['src']))
          .whereType<String>()
          .toList(),
      salons: summary.salons,
    );
  }

  String _text(Element? element) {
    if (element == null) return '';
    final copy = element.clone(true);
    for (final br in copy.querySelectorAll('br')) {
      br.replaceWith(Text(' '));
    }
    return copy.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _asset(Uri pageUrl, String? value) {
    if (value == null || value.trim().isEmpty || value.startsWith('#'))
      return null;
    final url = pageUrl.resolve(value.trim());
    return url.scheme == 'https' || url.scheme == 'http'
        ? url.toString()
        : null;
  }
}

class WebsiteBarberEntry {
  const WebsiteBarberEntry({required this.barber, this.profileUrl});
  final Barber barber;
  final Uri? profileUrl;
}
