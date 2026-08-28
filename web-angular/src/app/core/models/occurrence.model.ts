export type OccurrenceType =
  | 'DELIVERY_DELAY'
  | 'DAMAGE'
  | 'DELIVERY_FAILURE'
  | 'OTHER';

export type OccurrenceStatus = 'OPEN' | 'RESOLVED';

export interface CarrierOccurrence {
  id: number;
  carrierId: number;
  carrierName: string;
  type: OccurrenceType;
  description: string;
  status: OccurrenceStatus;
  createdAt: string;
  resolvedAt: string | null;
}

export interface OccurrencePage {
  content: CarrierOccurrence[];
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
}
