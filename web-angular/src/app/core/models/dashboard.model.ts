export interface ActivityHistoryItem {
  date: string;
  studyActivities: number;
  newRegistrations: number;
}

export interface LowStockProduct {
  productId: number;
  productName: string;
  sku: string;
  currentQuantity: number;
  minimumStock: number;
  status: 'NORMAL' | 'LOW_STOCK' | 'OUT_OF_STOCK';
}

export interface DashboardCarrier {
  carrierId: number;
  name: string;
  rating: number;
  slaPercentage: number;
  averageDeliveryDays: number;
}

export interface RecentOccurrence {
  occurrenceId: number;
  type: 'DELIVERY_DELAY' | 'DAMAGE' | 'DELIVERY_FAILURE' | 'OTHER';
  carrierName: string;
  createdAt: string;
  status: 'OPEN' | 'RESOLVED';
}

export interface DashboardResponse {
  educational: {
    registeredStudents: number;
    activeStudents: number;
    newRegistrations: number;
    inactiveRiskStudents: number;
    activityHistory: ActivityHistoryItem[];
  };
  operational: {
    registeredProducts: number;
    lowStockProducts: number;
    activeCarriers: number;
    openOccurrences: number;
    lowStock: LowStockProduct[];
    carriers: DashboardCarrier[];
    recentOccurrences: RecentOccurrence[];
  };
  executiveSummary: string;
}
