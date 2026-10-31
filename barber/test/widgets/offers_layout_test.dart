import 'package:barber/domain/models/website_offers_page_data.dart';
import 'package:barber/presentation/providers/website_offers_providers.dart';
import 'package:barber/presentation/screens/offers_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('all promotions fit a narrow screen at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final empty = WebsiteOffersPageData.unavailable(
        'voiron',
        Uri.parse('https://example.test/'),
      );
      final page = WebsiteOffersPageData(
        salonId: empty.salonId,
        pageUrl: empty.pageUrl,
        pageTitle: 'Offres',
        pageDescription: '',
        sections: [
          for (final title in ['-50 %', 'Barbe offerte'])
            WebsiteOfferSection.current(
              sectionLabel: 'En ce moment',
              badge: 'Offre du salon',
              headline: title,
              subheadline: 'Avec votre prestation dans le salon de Voiron',
              priceOld: '',
              priceNew: '',
              ctaLabel: 'Réserver ma prestation',
              footnote: 'Grenoble · Meylan · Voiron',
              details:
                  'Valable sur une cire achetée avec votre prestation, dans nos trois salons. '
                  'Réservez votre prestation auprès de votre barbier.',
              imageUrl: '',
            ),
        ],
        giftCard: empty.giftCard,
        conditions: const [],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            websiteOffersPagesProvider.overrideWith((ref) async => [page]),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const OffersListScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('-50 %'), findsOneWidget);
      expect(find.text('BARBE OFFERTE'), findsOneWidget);
      expect(find.text('30€'), findsNothing);
      await tester.ensureVisible(find.text('BARBE OFFERTE'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
