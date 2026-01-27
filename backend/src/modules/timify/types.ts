/**
 * TIMIFY API types
 * Client-safe types that never expose raw TIMIFY responses
 */

export type TimifyRegion = 'EUROPE' | 'US' | 'ASIA';

export interface TimifyCompany {
  id: string;
  name: string;
  address?: string;
  city?: string;
  country?: string;
  timezone?: string;
}

export interface TimifyService {
  id: string;
  name: string;
  duration: number;
  price?: number;
  currency?: string;
}

export interface TimifyAvailability {
  calendarBegin: string;
  calendarEnd: string;
  onDays: string[];
  offDays: string[];
  timesByDay?: Record<string, string[]>;
}

export interface TimifyReservationResponse {
  reservation_id: string;
  secret: string;
  expires_at: string;
}

export interface TimifyConfirmRequest {
  company_id: string;
  reservation_id: string;
  secret: string;
  external_customer_id: string;
  is_course: boolean;
  region: TimifyRegion;
}

export interface TimifyConfirmResponse {
  appointment_id?: string;
  status: string;
}
