export type CarrierStatus = 'ACTIVE' | 'INACTIVE';

export interface CarrierRequest {
  name: string;
  location: string;
  email: string;
  averageDeliveryDays: number;
  rating: number;
  slaPercentage: number;
  status: CarrierStatus;
}

export interface Carrier extends CarrierRequest {
  id: number;
  createdAt: string;
  updatedAt: string;
}

export interface CarrierPage {
  content: Carrier[];
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
}

export interface CarrierSummary {
  total: number;
  active: number;
  inactive: number;
}
