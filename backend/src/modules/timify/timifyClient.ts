/**
 * TIMIFY API client
 * Server-to-server only, never exposed to mobile app
 * Strict types, timeouts, limited retries, safe error mapping
 * 
 * IMPORTANT: Authentication
 * -------------------------
 * This client uses TIMIFY Booker Services endpoints which are PUBLIC and do NOT require authentication:
 * - /booker-services/companies
 * - /booker-services/availabilities
 * - /booker-services/reservations
 * - /booker-services/appointments/confirm
 * 
 * These endpoints are intentionally public and do not require:
 * - API keys
 * - Bearer tokens
 * - Query parameter authentication
 * - Any authentication headers
 * 
 * DO NOT add authentication headers (Authorization, X-API-Key, etc.) unless switching to
 * TIMIFY private/admin APIs. Adding auth to public Booker Services endpoints will cause requests to fail.
 */

import axios, { AxiosInstance, AxiosError } from 'axios';
import { logger } from '../../utils/logger';
import { AppError, ErrorCode } from '../../utils/errors';
import {
  timifyCompanySchema,
  timifyServiceSchema,
  timifyAvailabilityResponseSchema,
  timifyReservationResponseSchema,
  timifyConfirmResponseSchema,
  timifyErrorResponseSchema,
} from './schemas';
import type {
  TimifyCompany,
  TimifyService,
  TimifyAvailability,
  TimifyReservationResponse,
  TimifyConfirmRequest,
  TimifyConfirmResponse,
  TimifyRegion,
} from './types';

interface TimifyClientConfig {
  baseURL: string;
  region: TimifyRegion;
  timeout: number;
  maxRetries: number;
}

class TimifyClient {
  private client: AxiosInstance;
  private config: TimifyClientConfig;

  constructor(config: TimifyClientConfig) {
    this.config = config;
    this.client = axios.create({
      baseURL: config.baseURL,
      timeout: config.timeout,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    this.client.interceptors.request.use((config) => {
      const requestId = (global as { requestId?: string }).requestId || 
                       `req-${Date.now()}-${Math.random().toString(36).substring(7)}`;
      config.headers['X-Request-ID'] = requestId;
      return config;
    });
  }

  setMaxRetries(maxRetries: number): void {
    this.config.maxRetries = maxRetries;
  }

  private isRetryableError(error: unknown): boolean {
    if (!axios.isAxiosError(error)) {
      return false;
    }

    const axiosError = error as AxiosError;
    const status = axiosError.response?.status;

    if (!status) {
      return true;
    }

    return status >= 500 || status === 429;
  }

  private async requestWithRetry<T>(
    requestFn: () => Promise<T>,
    retriesLeft: number = this.config.maxRetries
  ): Promise<T> {
    try {
      return await requestFn();
    } catch (error) {
      if (retriesLeft > 0 && this.isRetryableError(error)) {
        logger.warn('TIMIFY request failed, retrying', {
          retriesLeft,
          error: axios.isAxiosError(error)
            ? error.message
            : String(error),
        });
        await new Promise((resolve) => setTimeout(resolve, 1000));
        return this.requestWithRetry(requestFn, retriesLeft - 1);
      }
      throw error;
    }
  }

  private mapTimifyError(error: unknown): AppError {
    if (axios.isAxiosError(error)) {
      const axiosError = error as AxiosError;
      const status = axiosError.response?.status;
      const data = axiosError.response?.data;

      if (data) {
        try {
          const errorData = timifyErrorResponseSchema.parse(data);
          const message = errorData.message || errorData.error || 'TIMIFY provider error';
          logger.error('TIMIFY API error', {
            status,
            message,
            code: errorData.code,
          });
        } catch {
          logger.error('TIMIFY API error (unparseable)', {
            status,
            data: JSON.stringify(data).substring(0, 200),
          });
        }
      }

      if (status === 400 || status === 422) {
        return new AppError(ErrorCode.BOOKING_VALIDATION_ERROR, 'Invalid booking request', 400);
      }

      if (status === 404) {
        return new AppError(ErrorCode.BOOKING_SLOT_UNAVAILABLE, 'Booking slot not available', 404);
      }

      if (status === 409) {
        return new AppError(ErrorCode.BOOKING_SLOT_UNAVAILABLE, 'Booking slot already taken', 409);
      }
    }

    logger.error('TIMIFY request failed', {
      error: error instanceof Error ? error.message : String(error),
    });

    return new AppError(ErrorCode.BOOKING_PROVIDER_ERROR, 'Booking service temporarily unavailable');
  }

  async getCompanies(): Promise<TimifyCompany[]> {
    try {
      const response = await this.requestWithRetry(() =>
        this.client.get('/booker-services/companies')
      );

      const companies = Array.isArray(response.data) ? response.data : [];
      return companies.map((company: unknown) => timifyCompanySchema.parse(company));
    } catch (error) {
      throw this.mapTimifyError(error);
    }
  }

  async getServices(companyId: string): Promise<TimifyService[]> {
    try {
      const response = await this.requestWithRetry(() =>
        this.client.get(`/booker-services/companies/${companyId}/services`)
      );

      const services = Array.isArray(response.data) ? response.data : [];
      return services.map((service: unknown) => timifyServiceSchema.parse(service));
    } catch (error) {
      throw this.mapTimifyError(error);
    }
  }

  async getAvailabilities(params: {
    company_id: string;
    service_id: string;
    start_date: string;
    end_date: string;
    resource_id?: string;
  }): Promise<TimifyAvailability> {
    try {
      const response = await this.requestWithRetry(() =>
        this.client.get('/booker-services/availabilities', { params })
      );

      const data = timifyAvailabilityResponseSchema.parse(response.data);

      const timesByDay: Record<string, string[]> = {};
      if (data.slots) {
        for (const slot of data.slots) {
          const date = slot.start.split('T')[0];
          if (!timesByDay[date]) {
            timesByDay[date] = [];
          }
          const time = slot.start.split('T')[1]?.substring(0, 5);
          if (time && !timesByDay[date].includes(time)) {
            timesByDay[date].push(time);
          }
        }
      }

      return {
        calendarBegin: data.calendar_begin,
        calendarEnd: data.calendar_end,
        onDays: data.on_days,
        offDays: data.off_days || [],
        timesByDay: Object.keys(timesByDay).length > 0 ? timesByDay : undefined,
      };
    } catch (error) {
      throw this.mapTimifyError(error);
    }
  }

  async createReservation(params: {
    company_id: string;
    service_id: string;
    date: string;
    time: string;
    resource_id?: string;
  }): Promise<TimifyReservationResponse> {
    try {
      const response = await this.requestWithRetry(() =>
        this.client.post('/booker-services/reservations', params)
      );

      const data = timifyReservationResponseSchema.parse(response.data);

      return {
        reservation_id: data.reservation_id,
        secret: data.secret,
        expires_at: data.expires_at,
      };
    } catch (error) {
      throw this.mapTimifyError(error);
    }
  }

  async confirmAppointment(request: TimifyConfirmRequest): Promise<TimifyConfirmResponse> {
    try {
      const response = await this.requestWithRetry(() =>
        this.client.post('/booker-services/appointments/confirm', request)
      );

      const data = timifyConfirmResponseSchema.parse(response.data);

      return {
        appointment_id: data.appointment_id,
        status: data.status,
      };
    } catch (error) {
      throw this.mapTimifyError(error);
    }
  }
}

export default TimifyClient;
