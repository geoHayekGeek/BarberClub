export interface PrivateClubRewardDefinition {
  slug: string;
  name: string;
  costPoints: number;
  description: string;
  imageUrl: string | null;
  sortOrder: number;
}

export const PRIVATE_CLUB_REWARDS: PrivateClubRewardDefinition[] = [
  {
    slug: 'product_30_percent',
    name: '30% off a product',
    costPoints: 75,
    description: 'Redeem for 30% off one product.',
    imageUrl: null,
    sortOrder: 10,
  },
  {
    slug: 'free_product',
    name: 'Free product',
    costPoints: 150,
    description: 'Redeem for one free product.',
    imageUrl: null,
    sortOrder: 20,
  },
  {
    slug: 'fragrance_20_percent',
    name: '20% off a fragrance',
    costPoints: 250,
    description: 'Redeem for 20% off one fragrance.',
    imageUrl: null,
    sortOrder: 30,
  },
  {
    slug: 'facial_or_beard_free',
    name: 'Free facial treatment OR free beard trim',
    costPoints: 300,
    description: 'Redeem for one free facial treatment or one free beard trim.',
    imageUrl: null,
    sortOrder: 40,
  },
];

export const PRIVATE_CLUB_REWARD_SLUGS = PRIVATE_CLUB_REWARDS.map((reward) => reward.slug);
