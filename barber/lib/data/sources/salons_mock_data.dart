import '../../domain/models/salon.dart';

/// Temporary static data source for salons.
/// Replace with backend API call later.
final List<Salon> salonsMockData = [
  Salon(
    id: '1',
    name: 'Barber Club Grenoble',
    city: 'Grenoble',
    descriptionShort: 'Notre salon historique au cœur de Grenoble. Ambiance premium et coupes sur-mesure.',
    descriptionLong:
        'Barber Club Grenoble est notre premier salon, ouvert au cœur de la ville. '
        'Un espace dédié à l\'art de la barberie : coupes classiques et modernes, rasages à l\'ancienne, '
        'soins de la barbe. Notre équipe vous accueille dans une atmosphère masculine et raffinée.',
    address: '12 rue de la République, 38000 Grenoble',
    images: [
      'assets/images/barber_background.jpg',
      'assets/images/barber_background.jpg',
      'assets/images/barber_background.jpg',
    ],
    openingHours: 'Mar–Sam 9h–19h, Dim–Lun fermé',
    services: ['Coupe homme', 'Barbe', 'Rasage', 'Soins'],
  ),
  Salon(
    id: '2',
    name: 'Barber Club Voiron',
    city: 'Voiron',
    descriptionShort: 'Salon spacieux à Voiron. Même exigence de qualité, même expérience Barber Club.',
    descriptionLong:
        'Notre salon de Voiron reprend l\'ADN Barber Club : un cadre soigné, des prestations premium '
        'et une équipe formée aux dernières tendances. Idéal pour les habitants du Voironnais '
        'qui ne veulent pas faire le déplacement jusqu\'à Grenoble.',
    address: '5 place du Marché, 38500 Voiron',
    images: [
      'assets/images/barber_background.jpg',
      'assets/images/barber_background.jpg',
    ],
    openingHours: 'Mar–Ven 9h30–19h, Sam 9h–18h, Dim–Lun fermé',
    services: ['Coupe homme', 'Barbe', 'Rasage'],
  ),
  Salon(
    id: '3',
    name: 'Barber Club Meylan',
    city: 'Meylan',
    descriptionShort: 'Votre Barber Club à Meylan. Proche et professionnel.',
    descriptionLong:
        'Le Barber Club Meylan vous propose les mêmes prestations que nos autres salons, '
        'dans un cadre moderne et confortable. Coupe, barbe, rasage et soins : tout pour une image soignée '
        'sans quitter Meylan.',
    address: '8 avenue Jean Jaurès, 38240 Meylan',
    images: [
      'assets/images/barber_background.jpg',
    ],
    openingHours: 'Mar–Sam 9h–19h, Dim–Lun fermé',
    services: ['Coupe homme', 'Barbe', 'Rasage', 'Soins', 'Coloration barbe'],
  ),
];
